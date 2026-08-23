import SwiftUI
import AppKit
import Combine

/// Mutable positions kept outside the published surface.
///
/// The layout produces new coordinates for every node up to sixty times a
/// second. Publishing an eight-thousand-element array at that rate would copy
/// it on every frame and thrash SwiftUI's diffing, so positions live in a
/// reference type the canvas reads directly, and only a small tick counter is
/// published to trigger the redraw.
final class LayoutStore {
    var x: [Double] = []
    var y: [Double] = []
    var settled = false

    func adopt(_ engine: LayoutEngine) {
        x = engine.x
        y = engine.y
    }

    func point(_ i: Int) -> CGPoint {
        guard i >= 0 && i < x.count else { return .zero }
        return CGPoint(x: x[i], y: y[i])
    }
}

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published state

    @Published private(set) var graph: CodeGraph?
    @Published private(set) var progress: Analyzer.Progress?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var layoutTick: Int = 0

    @Published var selection: Int?
    @Published var hovered: Int?
    @Published var searchText: String = ""
    @Published var showLabels: Bool = true
    @Published var includeExternal: Bool = false
    @Published var recentProjects: [URL] = []

    /// Requests the canvas fit the graph on the next draw.
    @Published var fitRequest: Int = 0

    let store = LayoutStore()

    private var engine: LayoutEngine?
    private var layoutTask: Task<Void, Never>?
    private let recentsKey = "uz.xarita.recents"

    // MARK: - Init

    init() {
        loadRecents()
    }

    // MARK: - Project lifecycle

    func chooseProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }

    func open(_ url: URL) {
        layoutTask?.cancel()
        layoutTask = nil
        engine = nil
        selection = nil
        hovered = nil
        errorMessage = nil
        isAnalyzing = true
        progress = Analyzer.Progress(stage: .scanning, current: 0, total: 0)

        let options = Analyzer.Options(includeExternal: includeExternal)

        // `AppState` is @MainActor-isolated and therefore implicitly Sendable,
        // so capturing it strongly here is safe — and avoids the nested weak
        // capture that Swift 6 rejects outright.
        Task.detached(priority: .userInitiated) { [self] in
            let result = Analyzer.analyze(root: url, options: options) { p in
                Task { @MainActor in self.progress = p }
            }
            await MainActor.run {
                self.finishAnalysis(result, url: url)
            }
        }
    }

    private func finishAnalysis(_ result: CodeGraph, url: URL) {
        isAnalyzing = false
        progress = nil

        guard !result.nodes.isEmpty else {
            graph = nil
            errorMessage = "empty"
            return
        }

        graph = result
        rememberRecent(url)

        var engine = LayoutEngine(graph: result)
        // A warm start: run the coarse phase synchronously so the first frame
        // already shows structure instead of a spiral of unsorted dots.
        engine.run(iterations: 24)
        self.engine = engine
        store.adopt(engine)
        store.settled = false
        layoutTick &+= 1
        fitRequest &+= 1

        Notifier.analysisFinished(project: result.projectName,
                                  symbols: result.nodes.count,
                                  seconds: result.parseSeconds)
        WidgetBridge.write(graph: result)

        startLayoutLoop()
    }

    // MARK: - Layout animation

    private func startLayoutLoop() {
        layoutTask?.cancel()
        layoutTask = Task { [self] in
            while !Task.isCancelled {
                guard var engine = self.engine else { return }

                // Several integration steps per frame: the simulation converges
                // in far fewer frames than it does steps, and stepping is cheap
                // relative to a redraw.
                let steps = engine.count > 4_000 ? 1 : 3
                for _ in 0..<steps { engine.step() }

                self.engine = engine
                self.store.adopt(engine)
                self.layoutTick &+= 1

                if engine.temperature <= 0.07 {
                    self.store.settled = true
                    return
                }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    func rerunLayout() {
        guard let graph else { return }
        var fresh = LayoutEngine(graph: graph)
        fresh.run(iterations: 24)
        engine = fresh
        store.adopt(fresh)
        store.settled = false
        layoutTick &+= 1
        fitRequest &+= 1
        startLayoutLoop()
    }

    func reanalyze() {
        guard let graph, !graph.rootPath.isEmpty else { return }
        open(URL(fileURLWithPath: graph.rootPath))
    }

    func closeProject() {
        layoutTask?.cancel()
        layoutTask = nil
        engine = nil
        graph = nil
        selection = nil
        hovered = nil
        errorMessage = nil
    }

    // MARK: - Queries

    /// Nodes whose name matches the current search, best matches first.
    var searchResults: [Int] {
        guard let graph, !searchText.isEmpty else { return [] }
        let needle = searchText.lowercased()
        return graph.nodes.indices
            .filter { graph.nodes[$0].name.lowercased().contains(needle)
                   || (graph.nodes[$0].container?.lowercased().contains(needle) ?? false) }
            .sorted { a, b in
                let na = graph.nodes[a].name.lowercased()
                let nb = graph.nodes[b].name.lowercased()
                let ea = na == needle, eb = nb == needle
                if ea != eb { return ea }
                let pa = na.hasPrefix(needle), pb = nb.hasPrefix(needle)
                if pa != pb { return pa }
                return graph.nodes[a].fanIn > graph.nodes[b].fanIn
            }
    }

    func select(_ id: Int?) {
        selection = id
    }

    // MARK: - Recents

    private func loadRecents() {
        let paths = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        recentProjects = paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func rememberRecent(_ url: URL) {
        var paths = recentProjects.map(\.path)
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        paths = Array(paths.prefix(8))
        UserDefaults.standard.set(paths, forKey: recentsKey)
        recentProjects = paths.map { URL(fileURLWithPath: $0) }
    }
}
