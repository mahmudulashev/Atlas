import Foundation

/// The small slice of a finished analysis the widget needs.
///
/// Deliberately tiny and self-contained: the widget process decodes this
/// without linking any of the analysis code.
struct Snapshot: Codable, Sendable {
    struct Hub: Codable, Sendable {
        var name: String
        var callers: Int
    }

    var projectName: String
    var projectPath: String
    var files: Int
    var lines: Int
    var symbols: Int
    var connections: Int
    var parseSeconds: Double
    var analysedAt: Date
    var topHubs: [Hub]
    var languages: [String]

    static let placeholder = Snapshot(
        projectName: "redis", projectPath: "~/code/redis",
        files: 333, lines: 241_121, symbols: 8_359, connections: 20_622,
        parseSeconds: 0.05, analysedAt: Date(),
        topHubs: [.init(name: "sdslen", callers: 476),
                  .init(name: "sdsfree", callers: 423),
                  .init(name: "zfree", callers: 370)],
        languages: ["C", "Python"])
}

/// Writes the snapshot the widget reads.
enum WidgetBridge {
    static func write(graph: CodeGraph) {
        SharedPaths.ensureDirectory()

        let hubs = graph.hubs(limit: 3).map {
            Snapshot.Hub(name: graph.nodes[$0].displayName, callers: graph.nodes[$0].fanIn)
        }
        let languages = graph.languageCounts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key.displayName)

        let snapshot = Snapshot(projectName: graph.projectName,
                                projectPath: graph.rootPath,
                                files: graph.files.count,
                                lines: graph.totalLines,
                                symbols: graph.nodes.count,
                                connections: graph.edges.count,
                                parseSeconds: graph.parseSeconds,
                                analysedAt: Date(),
                                topHubs: hubs,
                                languages: Array(languages))

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: SharedPaths.snapshotFile, options: .atomic)
        WidgetRefresher.reload()
    }

    static func read() -> Snapshot? {
        guard let data = try? Data(contentsOf: SharedPaths.snapshotFile) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
