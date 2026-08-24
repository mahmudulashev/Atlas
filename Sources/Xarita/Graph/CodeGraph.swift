import Foundation

/// One resolved declaration in the finished graph.
struct GraphNode: Identifiable, Sendable {
    let id: Int
    let name: String
    let container: String?
    let kind: SymbolKind
    let language: Language
    let fileIndex: Int
    let line: Int
    let endLine: Int

    var fanIn: Int = 0          // how many distinct symbols call this
    var fanOut: Int = 0         // how many distinct symbols this calls
    var isExternal: Bool = false

    var branches: Int = 0       // decision points inside the body
    var maxNesting: Int = 0     // deepest nesting reached

    /// How hard this is likely to be to read.
    ///
    /// Cyclomatic complexity alone under-reports deeply nested code, which is
    /// what actually defeats a beginner, so nesting is weighted separately and
    /// length contributes a little.
    enum Difficulty: Int, Comparable, Sendable {
        case easy, moderate, hard

        static func < (a: Difficulty, b: Difficulty) -> Bool { a.rawValue < b.rawValue }
    }

    var difficultyScore: Int {
        (branches + 1) + maxNesting * 2 + max(0, span - 20) / 15
    }

    var difficulty: Difficulty {
        switch difficultyScore {
        case ..<6:  return .easy
        case 6..<13: return .moderate
        default:    return .hard
        }
    }

    var displayName: String {
        if let container { return "\(container).\(name)" }
        return name
    }

    /// Lines of code spanned by the declaration.
    var span: Int { max(1, endLine - line + 1) }

    /// Weight used for node size — hubs should read as bigger.
    var weight: Double { Double(fanIn) * 1.6 + Double(fanOut) * 0.5 + 1 }
}

struct GraphEdge: Sendable {
    let from: Int
    let to: Int
    var count: Int
}

/// The finished, resolved picture of a codebase.
struct CodeGraph: Sendable {
    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []
    var files: [String] = []             // paths relative to the project root
    var rootPath: String = ""
    var projectName: String = ""

    /// Adjacency, built once so the UI can answer neighbour queries instantly.
    var outgoing: [[Int]] = []
    var incoming: [[Int]] = []

    var languageCounts: [Language: Int] = [:]
    var totalLines: Int = 0
    var parseSeconds: Double = 0

    /// File-to-file dependencies taken from imports, `<script src>` and the
    /// like. These carry the structure of a project whose files barely call
    /// each other's functions — a static site being the clearest case.
    var fileReferences: [(from: Int, to: Int)] = []

    // MARK: - Derived views

    /// Functions nothing calls — either entry points or dead code.
    var roots: [Int] {
        nodes.indices.filter { nodes[$0].fanIn == 0 && !nodes[$0].isExternal && nodes[$0].kind.isCallable }
    }

    /// The most-called symbols: where the codebase actually converges.
    func hubs(limit: Int = 12) -> [Int] {
        nodes.indices
            .filter { !nodes[$0].isExternal }
            .sorted { nodes[$0].fanIn > nodes[$1].fanIn }
            .prefix(limit)
            .filter { nodes[$0].fanIn > 0 }
    }

    /// Names that commonly indicate a real entry point rather than dead code.
    private static let entryNames: Set<String> = [
        "main", "Main", "init", "setUp", "setup", "run", "start", "handler", "Handler",
        "application", "applicationDidFinishLaunching", "body", "viewDidLoad", "test",
        "index", "default", "app", "App", "serve", "execute", "process", "__init__"
    ]

    /// Callables nothing reaches that also don't look like entry points.
    ///
    /// Deliberately conservative. Test files, framework callbacks and anything
    /// name-shaped like an entry point are excluded, because a name-resolved
    /// graph cannot see calls made through decorators, reflection or a router —
    /// so a bare fan-in of zero is suggestive, never proof.
    var unreachable: [Int] {
        roots.filter { idx in
            let n = nodes[idx]
            guard n.kind != .type else { return false }
            if Self.entryNames.contains(n.name) { return false }
            if n.name.hasPrefix("test") || n.name.hasPrefix("Test") { return false }
            if n.name.hasPrefix("_") { return false }
            if n.fileIndex >= 0 && n.fileIndex < files.count {
                let path = files[n.fileIndex].lowercased()
                for marker in ["test/", "tests/", "spec/", "specs/", "example/", "examples/",
                               "benchmark", "fixture", "mock", "demo/", "sample"]
                where path.contains(marker) { return false }
                let base = (path as NSString).lastPathComponent
                if base.hasPrefix("test") || base.contains("_test.") || base.contains(".test.")
                    || base.contains(".spec.") { return false }
            }
            return true
        }
    }

    /// How many distinct symbols this one can reach by following calls.
    ///
    /// The measure the atlas ranks entry points by: fan-out counts the first
    /// step only, and a function that calls one coordinator which calls forty
    /// things is a far better place to start reading than one that calls three
    /// leaves. Breadth-first, bounded, and cycle-safe.
    func reach(of id: Int, limit: Int = 400) -> Int {
        guard id >= 0, id < nodes.count else { return 0 }
        var seen: Set<Int> = [id]
        var queue = [id]
        var head = 0
        while head < queue.count, seen.count < limit {
            let current = queue[head]; head += 1
            for next in outgoing[current] where !nodes[next].isExternal {
                if seen.insert(next).inserted { queue.append(next) }
            }
        }
        return seen.count - 1
    }

    func neighbours(of id: Int) -> (callers: [Int], callees: [Int]) {
        guard id >= 0 && id < nodes.count else { return ([], []) }
        return (incoming[id], outgoing[id])
    }
}

/// Resolves per-file parse output into a single cross-file graph.
///
/// Resolution is name-based and scope-aware. Given `foo.bar()`, it prefers a
/// method named `bar` on a type named `foo`; failing that a `bar` declared in the
/// caller's own type, then one in the same file, then a unique match anywhere.
/// Unmatched names become external nodes, which is how third-party and stdlib
/// usage stays visible instead of silently vanishing.
struct GraphBuilder {

    struct FileResult {
        var path: String
        var symbols: [RawSymbol]
        var calls: [RawCall]
        var lines: Int
        var language: Language
        var references: [String] = []
    }

    static func build(from results: [FileResult],
                      rootPath: String,
                      projectName: String,
                      includeExternal: Bool) -> CodeGraph {

        var graph = CodeGraph()
        graph.rootPath = rootPath
        graph.projectName = projectName
        graph.files = results.map(\.path)

        // ---- 1. Flatten declarations into global nodes ----------------------
        var nodes: [GraphNode] = []
        var localToGlobal: [[Int]] = []          // per file, local symbol idx → node id

        for (fileIdx, result) in results.enumerated() {
            var map: [Int] = []
            map.reserveCapacity(result.symbols.count)
            for sym in result.symbols {
                let id = nodes.count
                var node = GraphNode(id: id, name: sym.name, container: sym.container,
                                     kind: sym.kind, language: sym.language,
                                     fileIndex: fileIdx, line: sym.line, endLine: sym.endLine)
                node.branches = sym.branches
                node.maxNesting = sym.maxNesting
                nodes.append(node)
                map.append(id)
            }
            localToGlobal.append(map)
            graph.totalLines += result.lines
            graph.languageCounts[result.language, default: 0] += 1
        }

        // ---- 2. Index by name for resolution --------------------------------
        var byName: [String: [Int]] = [:]
        var typeNames: Set<String> = []
        for node in nodes {
            byName[node.name, default: []].append(node.id)
            if node.kind == .type { typeNames.insert(node.name) }
        }

        var externalIDs: [String: Int] = [:]

        func externalNode(named name: String, language: Language) -> Int {
            if let existing = externalIDs[name] { return existing }
            let id = nodes.count
            var node = GraphNode(id: id, name: name, container: nil, kind: .function,
                                 language: language, fileIndex: -1, line: 0, endLine: 0)
            node.isExternal = true
            nodes.append(node)
            externalIDs[name] = id
            return id
        }

        // ---- 3. Resolve every call to a node --------------------------------
        var edgeMap: [Int64: Int] = [:]          // packed (from,to) → count
        edgeMap.reserveCapacity(results.reduce(0) { $0 + $1.calls.count })

        @inline(__always)
        func pack(_ a: Int, _ b: Int) -> Int64 { Int64(a) << 32 | Int64(UInt32(truncatingIfNeeded: b)) }

        for (fileIdx, result) in results.enumerated() {
            for call in result.calls {
                guard call.callerSymbol >= 0,
                      call.callerSymbol < localToGlobal[fileIdx].count else { continue }
                let fromID = localToGlobal[fileIdx][call.callerSymbol]

                var candidates = byName[call.calleeName] ?? []
                candidates.removeAll { nodes[$0].kind == .type }

                var target: Int? = nil

                if candidates.isEmpty {
                    // Never resolved anywhere in the project → third party.
                    if includeExternal, !call.calleeName.isEmpty {
                        target = externalNode(named: call.calleeName, language: result.language)
                    }
                } else if candidates.count == 1 {
                    target = candidates[0]
                } else {
                    // a) receiver names a known type → prefer its member
                    if let recv = call.receiver, typeNames.contains(recv),
                       let hit = candidates.first(where: { nodes[$0].container == recv }) {
                        target = hit
                    }
                    // b) same container as the caller
                    if target == nil {
                        let callerContainer = nodes[fromID].container
                        if let c = callerContainer,
                           let hit = candidates.first(where: { nodes[$0].container == c }) {
                            target = hit
                        }
                    }
                    // c) same file
                    if target == nil,
                       let hit = candidates.first(where: { nodes[$0].fileIndex == fileIdx }) {
                        target = hit
                    }
                    // d) give up gracefully: most-connected candidate
                    if target == nil { target = candidates.first }
                }

                guard let toID = target, toID != fromID else { continue }
                edgeMap[pack(fromID, toID), default: 0] += 1
            }
        }

        // ---- 4. Materialise edges and degree counts -------------------------
        var edges: [GraphEdge] = []
        edges.reserveCapacity(edgeMap.count)
        var outgoing = [[Int]](repeating: [], count: nodes.count)
        var incoming = [[Int]](repeating: [], count: nodes.count)

        for (key, count) in edgeMap {
            let from = Int(key >> 32)
            let to = Int(Int32(truncatingIfNeeded: key))
            guard from >= 0, from < nodes.count, to >= 0, to < nodes.count else { continue }
            edges.append(GraphEdge(from: from, to: to, count: count))
            outgoing[from].append(to)
            incoming[to].append(from)
        }

        for i in nodes.indices {
            nodes[i].fanOut = outgoing[i].count
            nodes[i].fanIn = incoming[i].count
        }

        // ---- 5. File-level references ----
        var pathIndex: [String: Int] = [:]
        for (index, path) in graph.files.enumerated() {
            pathIndex[(path as NSString).standardizingPath] = index
        }
        var seenReferences = Set<Int64>()
        for (fileIndex, result) in results.enumerated() {
            for reference in result.references {
                guard let target = References.resolve(reference, from: result.path,
                                                      index: pathIndex),
                      target != fileIndex else { continue }
                let key = Int64(fileIndex) << 32 | Int64(target)
                if seenReferences.insert(key).inserted {
                    graph.fileReferences.append((from: fileIndex, to: target))
                }
            }
        }

        graph.nodes = nodes
        graph.edges = edges
        graph.outgoing = outgoing
        graph.incoming = incoming
        return graph
    }
}
