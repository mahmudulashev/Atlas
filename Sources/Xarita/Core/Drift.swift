import Foundation

/// What changed in the graph since the last time this project was scanned.
///
/// Everything else in Xarita describes a codebase as it is now. Drift is the
/// only view with a memory, and it is the one that answers the question a
/// returning developer actually has — not "what is this project" but "what
/// moved while I was away". A snapshot of the measurements is written after
/// every scan; the next scan diffs against it.
struct Drift: Sendable {

    enum Kind: String, Sendable {
        case newCycle          // files that now depend on each other and did not
        case grew              // a function got longer or more branching
        case shrank
        case gainedCallers     // more of the codebase leans on it now
        case lostCallers       // migration away from it is working
        case appeared
        case vanished
    }

    struct Entry: Identifiable, Sendable {
        let id: Int
        let kind: Kind
        let subject: String
        let delta: Int          // signed, for the "+38" / "−2" figure
        let detail: String      // second number, when there is one

        /// Which ink carries it. Structural regressions take magenta —
        /// the upstream ink — because a new cycle is something reaching back.
        /// Improvements take cyan. Plain growth is set in ink.
        var isRegression: Bool { kind == .newCycle || kind == .gainedCallers }
        var isImprovement: Bool { kind == .lostCallers || kind == .shrank }
    }

    var entries: [Entry] = []
    var previousScan: Date?

    var isEmpty: Bool { entries.isEmpty }
}

/// The measurements kept between scans. Deliberately small — names and three
/// numbers each — so a large project's history stays a few hundred kilobytes.
struct ProjectSnapshotRecord: Codable, Sendable {
    struct SymbolRecord: Codable, Sendable {
        var span: Int
        var branches: Int
        var callers: Int
    }

    var scannedAt: Date
    var symbols: [String: SymbolRecord]
    var cycles: [String]
    var fileCount: Int
    var symbolCount: Int
}

enum DriftStore {

    private static func file(for projectPath: String) -> URL {
        // One file per project, keyed by a hash of the path so the name stays
        // short and legal whatever the folder is called.
        var hash: UInt64 = 5381
        for byte in projectPath.utf8 { hash = hash &* 33 &+ UInt64(byte) }
        return SharedPaths.supportDirectory
            .appendingPathComponent("history", isDirectory: true)
            .appendingPathComponent(String(format: "%016llx.json", hash), isDirectory: false)
    }

    static func record(from graph: CodeGraph, fileGraph: FileGraph) -> ProjectSnapshotRecord {
        var symbols: [String: ProjectSnapshotRecord.SymbolRecord] = [:]
        symbols.reserveCapacity(graph.nodes.count)
        for node in graph.nodes where !node.isExternal && node.kind.isCallable {
            let key = node.fileIndex >= 0 && node.fileIndex < graph.files.count
                ? "\(graph.files[node.fileIndex])#\(node.displayName)"
                : node.displayName
            symbols[key] = .init(span: node.span, branches: node.branches, callers: node.fanIn)
        }
        let cycles = fileGraph.cycles.map { cycle in
            cycle.map { fileGraph.nodes[$0].name }.sorted().joined(separator: "|")
        }
        return ProjectSnapshotRecord(scannedAt: Date(), symbols: symbols, cycles: cycles,
                                     fileCount: graph.files.count,
                                     symbolCount: graph.nodes.count)
    }

    static func load(projectPath: String) -> ProjectSnapshotRecord? {
        guard let data = try? Data(contentsOf: file(for: projectPath)) else { return nil }
        return try? JSONDecoder().decode(ProjectSnapshotRecord.self, from: data)
    }

    static func save(_ record: ProjectSnapshotRecord, projectPath: String) {
        let url = file(for: projectPath)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Compares two scans, most significant change first.
    ///
    /// Thresholds exist because everything moves a little: a function that
    /// gained one line is noise, and a list of noise is a list nobody reads.
    static func compare(previous: ProjectSnapshotRecord,
                        current: ProjectSnapshotRecord,
                        limit: Int = 8) -> Drift {
        var entries: [Drift.Entry] = []
        var id = 0
        func next() -> Int { defer { id += 1 }; return id }

        // ---- Cycles that are new ----
        let before = Set(previous.cycles)
        for cycle in current.cycles where !before.contains(cycle) {
            let names = cycle.split(separator: "|").prefix(3).joined(separator: " → ")
            entries.append(.init(id: next(), kind: .newCycle, subject: names,
                                 delta: 1, detail: ""))
        }

        // ---- Symbols that changed shape ----
        for (key, now) in current.symbols {
            guard let then = previous.symbols[key] else { continue }
            let name = key.contains("#") ? String(key.split(separator: "#").last!) : key

            let lineDelta = now.span - then.span
            if abs(lineDelta) >= 12 {
                entries.append(.init(id: next(),
                                     kind: lineDelta > 0 ? .grew : .shrank,
                                     subject: name, delta: lineDelta,
                                     detail: now.branches != then.branches
                                             ? "\(now.branches - then.branches)" : ""))
            }

            let callerDelta = now.callers - then.callers
            if abs(callerDelta) >= 2 {
                entries.append(.init(id: next(),
                                     kind: callerDelta > 0 ? .gainedCallers : .lostCallers,
                                     subject: name, delta: callerDelta, detail: ""))
            }
        }

        // ---- Whole symbols coming and going ----
        let appeared = Set(current.symbols.keys).subtracting(previous.symbols.keys)
        let vanished = Set(previous.symbols.keys).subtracting(current.symbols.keys)
        if appeared.count >= 3 {
            entries.append(.init(id: next(), kind: .appeared,
                                 subject: "", delta: appeared.count, detail: ""))
        }
        if vanished.count >= 3 {
            entries.append(.init(id: next(), kind: .vanished,
                                 subject: "", delta: -vanished.count, detail: ""))
        }

        // A new cycle outranks everything; after that, the biggest movement.
        entries.sort { a, b in
            if (a.kind == .newCycle) != (b.kind == .newCycle) { return a.kind == .newCycle }
            return abs(a.delta) > abs(b.delta)
        }

        var drift = Drift()
        drift.entries = Array(entries.prefix(limit))
        drift.previousScan = previous.scannedAt
        return drift
    }
}
