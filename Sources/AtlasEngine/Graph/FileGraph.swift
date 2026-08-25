import Foundation

/// Which part of a program a file belongs to.
///
/// Inferred from path and imports rather than declared, because no project
/// states this anywhere — yet it is the first thing a newcomer wants to know
/// about a file they have just opened.
enum Layer: String, CaseIterable, Sendable {
    case entry, ui, api, logic, data, model, config, test, util

    var uz: String {
        switch self {
        case .entry:  return "kirish"
        case .ui:     return "interfeys"
        case .api:    return "tarmoq"
        case .logic:  return "mantiq"
        case .data:   return "maʼlumot"
        case .model:  return "model"
        case .config: return "sozlama"
        case .test:   return "test"
        case .util:   return "yordamchi"
        }
    }

    var en: String {
        switch self {
        case .entry:  return "entry"
        case .ui:     return "interface"
        case .api:    return "network"
        case .logic:  return "logic"
        case .data:   return "storage"
        case .model:  return "model"
        case .config: return "config"
        case .test:   return "test"
        case .util:   return "utility"
        }
    }

    func name(_ language: AppLanguage) -> String { language == .uz ? uz : en }

    /// Rank used to order layers top-to-bottom in the diagram: what the user
    /// touches first sits highest, storage sits lowest.
    var depth: Int {
        switch self {
        case .entry:  return 0
        case .ui:     return 1
        case .api:    return 2
        case .logic:  return 3
        case .model:  return 4
        case .data:   return 5
        case .util:   return 6
        case .config: return 7
        case .test:   return 8
        }
    }

    static func classify(path: String, symbols: [String]) -> Layer {
        let p = path.lowercased()
        let last = P.lastComponent(p)

        for marker in ["test", "spec", "__tests__", "fixture", "mock"]
        where p.contains(marker) { return .test }

        for marker in ["config", "settings", ".env", "constants", "webpack", "vite",
                       "tsconfig", "package.json", "makefile", "dockerfile"]
        where p.contains(marker) { return .config }

        for marker in ["main.", "index.", "app.", "__main__", "cli.", "bin/", "cmd/", "entry"]
        where last.hasPrefix(marker) || p.contains("/" + marker) { return .entry }

        // Apple projects name the launch file after the app — AtlasApp.swift,
        // MyThingApp.swift — and it never matches a prefix rule.
        let stem = P.deletingExtension(last)
        if stem.hasSuffix("app") || stem.hasSuffix("main") || stem.hasSuffix("delegate") {
            return .entry
        }

        for marker in ["component", "view", "page", "screen", "widget", "ui/", "/ui",
                       ".tsx", ".jsx", "template", "layout", "style", "render"]
        where p.contains(marker) { return .ui }

        for marker in ["route", "controller", "handler", "endpoint", "api/", "/api",
                       "server", "http", "request", "client", "socket", "rpc", "graphql"]
        where p.contains(marker) { return .api }

        for marker in ["model", "entity", "schema", "type", "dto", "struct"]
        where p.contains(marker) { return .model }

        for marker in ["repository", "store", "database", "/db", "db/", "query", "migration",
                       "cache", "storage", "persist", "dao"]
        where p.contains(marker) { return .data }

        for marker in ["util", "helper", "common", "shared", "tool", "format", "misc"]
        where p.contains(marker) { return .util }

        for marker in ["service", "manager", "engine", "core", "domain", "usecase",
                       "processor", "analyzer", "parser"]
        where p.contains(marker) { return .logic }

        // Nothing in the path said anything — fall back to what the file does.
        let joined = symbols.joined(separator: " ").lowercased()
        if joined.contains("render") || joined.contains("draw") || joined.contains("view") { return .ui }
        if joined.contains("fetch") || joined.contains("request") { return .api }
        if joined.contains("save") || joined.contains("load") || joined.contains("query") { return .data }
        return .logic
    }
}

/// The codebase seen one level up: files as nodes, "calls into" as edges.
///
/// The symbol-level graph is the truth but it is not a picture — a real project
/// has thousands of functions and any drawing of them is a hairball. Files are
/// the level a person already thinks in, there are one or two orders of
/// magnitude fewer of them, and each one carries enough content to be worth
/// drawing as a card rather than a dot.
struct FileGraph: Sendable {

    struct Node: Identifiable, Sendable {
        let id: Int                 // index into CodeGraph.files
        let path: String
        let name: String            // last path component
        let directory: String
        let layer: Layer
        let language: Language
        var symbols: [Int]          // symbol ids, most connected first
        var symbolCount: Int
        var lines: Int
        var fanIn: Int = 0
        var fanOut: Int = 0
        var column: Int = 0         // assigned by layout
        var row: Int = 0
    }

    struct Edge: Sendable {
        let from: Int
        let to: Int
        var weight: Int             // number of distinct call sites
    }

    var nodes: [Node] = []
    var edges: [Edge] = []
    var outgoing: [[Int]] = []
    var incoming: [[Int]] = []

    /// Files that depend on each other in a cycle — worth flagging, since a
    /// cycle is the thing that makes a codebase hard to change safely.
    var cycles: [[Int]] = []

    // MARK: - Construction

    static func build(from graph: CodeGraph,
                      maxNodes: Int = 60,
                      maxEdges: Int = 130,
                      includeTests: Bool = false) -> FileGraph {
        guard !graph.files.isEmpty else { return FileGraph() }

        // Group symbols by file.
        var symbolsByFile: [[Int]] = Array(repeating: [], count: graph.files.count)
        var linesByFile = [Int](repeating: 0, count: graph.files.count)
        for node in graph.nodes where node.fileIndex >= 0 && node.fileIndex < graph.files.count {
            symbolsByFile[node.fileIndex].append(node.id)
            linesByFile[node.fileIndex] = max(linesByFile[node.fileIndex], node.endLine)
        }

        // Rank files by how connected they are, and keep the most significant —
        // a diagram of four hundred cards is the hairball again in card form.
        var weight = [Int](repeating: 0, count: graph.files.count)
        for edge in graph.edges {
            let a = graph.nodes[edge.from].fileIndex
            let b = graph.nodes[edge.to].fileIndex
            if a >= 0 { weight[a] += 1 }
            if b >= 0, b != a { weight[b] += 1 }
        }
        // Tests double the card count and add nothing to the picture of how
        // the program itself is wired, so they are out unless asked for.
        let eligible = graph.files.indices.filter { index in
            guard !symbolsByFile[index].isEmpty else { return false }
            if includeTests { return true }
            let names = symbolsByFile[index].prefix(6).map { graph.nodes[$0].name }
            return Layer.classify(path: graph.files[index], symbols: names) != .test
        }
        let kept = Set(eligible.sorted { weight[$0] > weight[$1] }.prefix(maxNodes))

        var result = FileGraph()
        var indexMap: [Int: Int] = [:]

        for fileIndex in graph.files.indices where kept.contains(fileIndex) {
            let path = graph.files[fileIndex]
            // One row per distinct name. A file with three initialisers should
            // not spend three of its six visible rows saying "init", and a type
            // and its extension are one thing to a reader, not two.
            var seenNames = Set<String>()
            let symbols = symbolsByFile[fileIndex]
                .sorted { a, b in
                    let na = graph.nodes[a], nb = graph.nodes[b]
                    let wa = na.fanIn * 2 + na.fanOut, wb = nb.fanIn * 2 + nb.fanOut
                    if wa != wb { return wa > wb }
                    // Prefer things that do something over bare declarations.
                    if (na.kind == .type) != (nb.kind == .type) { return nb.kind == .type }
                    return na.span > nb.span
                }
                .filter { seenNames.insert(graph.nodes[$0].name).inserted }
            let names = symbols.prefix(12).map { graph.nodes[$0].name }
            let language = symbols.first.map { graph.nodes[$0].language } ?? .swift

            indexMap[fileIndex] = result.nodes.count
            result.nodes.append(Node(
                id: fileIndex,
                path: path,
                name: P.lastComponent(path),
                directory: P.deletingLastComponent(path),
                layer: Layer.classify(path: path, symbols: names),
                language: language,
                symbols: Array(symbols.prefix(8)),
                symbolCount: symbols.count,
                lines: linesByFile[fileIndex]))
        }

        // Collapse symbol edges into file edges.
        var edgeWeights: [Int64: Int] = [:]

        // An explicit import or <script src> is a stronger statement of
        // dependency than any single call site, so it is seeded with weight
        // rather than merely counted.
        for reference in graph.fileReferences {
            guard let from = indexMap[reference.from], let to = indexMap[reference.to],
                  from != to else { continue }
            edgeWeights[Int64(from) << 32 | Int64(to), default: 0] += 3
        }

        for edge in graph.edges {
            let a = graph.nodes[edge.from].fileIndex
            let b = graph.nodes[edge.to].fileIndex
            guard a >= 0, b >= 0, a != b,
                  let from = indexMap[a], let to = indexMap[b] else { continue }
            edgeWeights[Int64(from) << 32 | Int64(to), default: 0] += edge.count
        }

        // Densely-connected codebases — C projects especially — produce more
        // edges than any drawing can carry: Redis yields over eight hundred
        // between seventy files. Keeping the heaviest dependencies preserves
        // the shape of the system while leaving a picture that can be read.
        // Weight is the number of distinct call sites, so what survives is what
        // the files actually lean on.
        // Ties break on the key, not on chance. Sorting by weight alone left
        // equally-weighted edges in the dictionary's own order, which Swift
        // reseeds per process — so which dependencies survived the cut, and
        // the order of those that did, changed between runs of the same scan.
        let ranked = edgeWeights
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(maxEdges)

        result.outgoing = Array(repeating: [], count: result.nodes.count)
        result.incoming = Array(repeating: [], count: result.nodes.count)
        for (key, count) in ranked {
            let from = Int(key >> 32), to = Int(Int32(truncatingIfNeeded: key))
            result.edges.append(Edge(from: from, to: to, weight: count))
            result.outgoing[from].append(to)
            result.incoming[to].append(from)
        }
        for i in result.nodes.indices {
            result.nodes[i].fanOut = result.outgoing[i].count
            result.nodes[i].fanIn = result.incoming[i].count
        }

        result.cycles = findCycles(in: result)
        return result
    }

    // MARK: - Cycles

    /// Tarjan's strongly connected components. Any component with more than one
    /// file is a dependency cycle.
    private static func findCycles(in graph: FileGraph) -> [[Int]] {
        var index = 0
        var indices = [Int](repeating: -1, count: graph.nodes.count)
        var low = [Int](repeating: 0, count: graph.nodes.count)
        var onStack = [Bool](repeating: false, count: graph.nodes.count)
        var stack: [Int] = []
        var components: [[Int]] = []

        func strongConnect(_ v: Int) {
            indices[v] = index
            low[v] = index
            index += 1
            stack.append(v)
            onStack[v] = true

            for w in graph.outgoing[v] {
                if indices[w] == -1 {
                    strongConnect(w)
                    low[v] = min(low[v], low[w])
                } else if onStack[w] {
                    low[v] = min(low[v], indices[w])
                }
            }

            if low[v] == indices[v] {
                var component: [Int] = []
                while let w = stack.popLast() {
                    onStack[w] = false
                    component.append(w)
                    if w == v { break }
                }
                if component.count > 1 { components.append(component) }
            }
        }

        for v in graph.nodes.indices where indices[v] == -1 { strongConnect(v) }
        return components
    }
}
