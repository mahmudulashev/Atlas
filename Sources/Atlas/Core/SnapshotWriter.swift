import Foundation

/// Writes the snapshot the widget reads.
extension WidgetBridge {
    static func write(graph: CodeGraph,
                      issues: [Issue] = [],
                      kind: ProjectKind = .library,
                      routeSteps: Int = 0,
                      routeDone: Int = 0) {
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
                                routeDone: routeDone)

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: SharedPaths.snapshotFile, options: .atomic)
        WidgetRefresher.reload()
    }
}
