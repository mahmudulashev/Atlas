import Foundation

/// Writes the snapshot the widget reads.
extension WidgetBridge {

    /// Called after every successful write.
    ///
    /// The macOS app points this at WidgetKit so a finished scan refreshes
    /// the widget. Nothing else does: the Windows build has no widget, and
    /// the headless engine has no UI to nudge. A hook rather than an `#if`
    /// because the engine also builds standalone *on* macOS, where the app's
    /// WidgetKit code is not linked in.
    nonisolated(unsafe) static var didWrite: (() -> Void)?

    static func write(graph: CodeGraph,
                      issues: [Issue] = [],
                      kind: ProjectKind = .library,
                      routeSteps: Int = 0,
                      routeDone: Int = 0,
                      language: AppLanguage = .en) {
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
                                languages: Array(languages),
                                issueCount: issues.count,
                                highIssueCount: issues.filter { $0.severity == .high }.count,
                                kind: kind.rawValue,
                                routeSteps: routeSteps,
                                routeDone: routeDone,
                                language: language.rawValue)

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: SharedPaths.snapshotFile, options: .atomic)
        didWrite?()
    }
}
