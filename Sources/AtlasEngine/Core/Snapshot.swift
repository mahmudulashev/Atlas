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
    var issueCount: Int
    var highIssueCount: Int
    var kind: String
    var routeSteps: Int
    var routeDone: Int

    /// The interface language at the time of writing. The widget runs in its
    /// own process and cannot read the app's settings, so the choice travels
    /// with the data.
    var language: String = "en"

    static let placeholder = Snapshot(
        projectName: "redis", projectPath: "~/code/redis",
        files: 333, lines: 241_121, symbols: 8_359, connections: 20_622,
        parseSeconds: 0.05, analysedAt: Date(),
        topHubs: [.init(name: "sdslen", callers: 476),
                  .init(name: "sdsfree", callers: 423),
                  .init(name: "zfree", callers: 370)],
        languages: ["C", "Python"],
        issueCount: 50, highIssueCount: 12,
        kind: "server", routeSteps: 6, routeDone: 2, language: "en")
}

/// Reading is shared with the widget; writing is not, since it needs the
/// analysis types that only the app links.
enum WidgetBridge {
    static func read() -> Snapshot? {
        guard let data = try? Data(contentsOf: SharedPaths.snapshotFile) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
