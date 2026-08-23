import SwiftUI
import AppKit
import Combine

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published state

    /// The window shows one of two things: an orientation on the project as a
    /// whole, or the reading view for a single step. Opening straight into a
    /// function was the old behaviour and it is precisely what leaves a
    /// newcomer with no idea where they are.
    enum Mode { case orientation, architecture, issues, reading }

    @Published private(set) var graph: CodeGraph?
    @Published private(set) var mode: Mode = .orientation
    @Published private(set) var route: Route = Route(steps: [])
    @Published private(set) var fileGraph = FileGraph()
    @Published private(set) var diagram = DiagramLayout(graph: FileGraph())
    @Published private(set) var issues: [Issue] = []
    @Published var showTestsInDiagram = false {
        didSet { rebuildDiagram() }
    }
    @Published private(set) var projectKind: ProjectKind = .library
    @Published private(set) var progress: Analyzer.Progress?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var errorMessage: String?

    @Published var selection: Int? {
        didSet {
            guard selection != oldValue else { return }
            pendingExplanation = true
            if !isNavigatingHistory { pushHistory(selection) }
        }
    }

    /// Functions the reader has ticked off, as stable signatures rather than
    /// node ids — ids are assigned per analysis and would not survive a
    /// re-scan, but `file#name#line` does.
    @Published private(set) var understood: Set<String> = []

    @Published private(set) var history: [Int?] = []
    @Published private(set) var historyIndex: Int = -1
    private var isNavigatingHistory = false
    @Published var searchText: String = ""
    @Published var includeExternal: Bool = false
    @Published var recentProjects: [URL] = []

    let sourceCache = SourceCache()

    /// Set when the selection changes, so the explanation panel knows the
    /// cached text no longer matches what is on screen.
    private var pendingExplanation = false

    private let recentsKey = "uz.xarita.recents"

    init() { loadRecents() }

    // MARK: - Project lifecycle

    /// The caller supplies the button title so the panel speaks the interface
    /// language rather than the system one.
    func chooseProject(prompt: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        panel.message = prompt
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func open(_ url: URL) {
        selection = nil
        errorMessage = nil
        isAnalyzing = true
        progress = Analyzer.Progress(stage: .scanning, current: 0, total: 0)

        let options = Analyzer.Options(includeExternal: includeExternal)

        // `AppState` is @MainActor-isolated and therefore implicitly Sendable,
        // so capturing it strongly here is safe.
        Task.detached(priority: .userInitiated) { [self] in
            let result = Analyzer.analyze(root: url, options: options) { p in
                Task { @MainActor in self.progress = p }
            }
            await MainActor.run { self.finishAnalysis(result, url: url) }
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
        history = []
        historyIndex = -1
        loadUnderstood()

        route = Route.build(from: result)
        projectKind = ProjectKind.heuristic(for: result)
        rebuildDiagram()
        mode = .orientation
        selection = route.nodeIDs.first

        Notifier.analysisFinished(project: result.projectName,
                                  symbols: result.nodes.count,
                                  seconds: result.parseSeconds)
        WidgetBridge.write(graph: result)
    }

    func reanalyze() {
        guard let graph, !graph.rootPath.isEmpty else { return }
        open(URL(fileURLWithPath: graph.rootPath))
    }

    func closeProject() {
        graph = nil
        selection = nil
        errorMessage = nil
        searchText = ""
        route = Route(steps: [])
        fileGraph = FileGraph()
        diagram = DiagramLayout(graph: FileGraph())
        issues = []
        mode = .orientation
    }

    /// Refines the heuristic guess with the on-device model, when available.
    func refineProjectKind(using explainer: Explainer) {
        guard let graph else { return }
        Task { [weak self] in
            if let kind = await explainer.classifyProject(graph: graph) {
                await MainActor.run { self?.projectKind = kind }
            }
        }
    }

    // MARK: - Diagram

    private func rebuildDiagram() {
        guard let graph else {
            fileGraph = FileGraph()
            diagram = DiagramLayout(graph: FileGraph())
            issues = []
            return
        }
        fileGraph = FileGraph.build(from: graph, includeTests: showTestsInDiagram)
        diagram = DiagramLayout(graph: fileGraph)
        issues = IssueFinder.find(graph: graph, fileGraph: fileGraph)
    }

    func showArchitecture() { mode = .architecture }
    func showIssues() { mode = .issues }

    // MARK: - Route

    /// Index of the current selection within the route, when it is on it.
    var currentStepIndex: Int? {
        guard let selection else { return nil }
        return route.nodeIDs.firstIndex(of: selection)
    }

    var canGoNextStep: Bool {
        guard let i = currentStepIndex else { return !route.isEmpty }
        return i + 1 < route.steps.count
    }

    var canGoPreviousStep: Bool { (currentStepIndex ?? 0) > 0 }

    func beginReading() {
        guard !route.isEmpty else { return }
        selection = route.nodeIDs.first
        mode = .reading
    }

    func showOrientation() { mode = .orientation }

    func openStep(_ index: Int) {
        guard index >= 0, index < route.steps.count else { return }
        selection = route.steps[index].nodeID
        mode = .reading
    }

    func nextStep() {
        guard let i = currentStepIndex else { openStep(0); return }
        openStep(i + 1)
    }

    func previousStep() {
        guard let i = currentStepIndex, i > 0 else { return }
        openStep(i - 1)
    }

    /// How much of the route has been ticked off.
    var routeProgress: (done: Int, total: Int) {
        let done = route.nodeIDs.filter { isUnderstood($0) }.count
        return (done, route.steps.count)
    }

    // MARK: - Selection and history

    func select(_ id: Int?) {
        selection = id
        if mode == .orientation { mode = .reading }
    }

    private func pushHistory(_ id: Int?) {
        if historyIndex < history.count - 1 {
            history.removeSubrange((historyIndex + 1)...)
        }
        history.append(id)
        if history.count > 100 { history.removeFirst() }
        historyIndex = history.count - 1
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex >= 0 && historyIndex < history.count - 1 }

    func goBack() {
        guard canGoBack else { return }
        isNavigatingHistory = true
        historyIndex -= 1
        selection = history[historyIndex]
        isNavigatingHistory = false
    }

    func goForward() {
        guard canGoForward else { return }
        isNavigatingHistory = true
        historyIndex += 1
        selection = history[historyIndex]
        isNavigatingHistory = false
    }

    // MARK: - Reading progress

    /// A signature that survives re-analysis of the same project.
    func signature(for node: GraphNode, in graph: CodeGraph) -> String {
        let file = node.fileIndex >= 0 && node.fileIndex < graph.files.count
            ? graph.files[node.fileIndex] : "?"
        return "\(file)#\(node.displayName)#\(node.line)"
    }

    func isUnderstood(_ id: Int) -> Bool {
        guard let graph, id < graph.nodes.count else { return false }
        return understood.contains(signature(for: graph.nodes[id], in: graph))
    }

    func toggleUnderstood(_ id: Int) {
        guard let graph, id < graph.nodes.count else { return }
        let key = signature(for: graph.nodes[id], in: graph)
        if understood.contains(key) { understood.remove(key) } else { understood.insert(key) }
        saveUnderstood()
    }

    /// Progress against the functions actually worth reading — external nodes
    /// and bare type declarations are not something you "read".
    var readableCount: Int {
        guard let graph else { return 0 }
        return graph.nodes.filter { !$0.isExternal && $0.kind.isCallable }.count
    }

    private var understoodKey: String {
        "uz.xarita.understood." + (graph?.rootPath ?? "none")
    }

    private func saveUnderstood() {
        UserDefaults.standard.set(Array(understood), forKey: understoodKey)
    }

    private func loadUnderstood() {
        understood = Set(UserDefaults.standard.stringArray(forKey: understoodKey) ?? [])
    }

    /// Asks the on-device model to describe the current selection.
    func requestExplanation(explainer: Explainer, language: AppLanguage) {
        guard let graph, let id = selection, id < graph.nodes.count else { return }
        let node = graph.nodes[id]
        guard let snippet = sourceCache.snippet(for: node, in: graph) else { return }
        explainer.explain(node: node, graph: graph, source: snippet.text, language: language)
        pendingExplanation = false
    }

    // MARK: - Junior-friendly entry points

    /// Where a newcomer should start reading: the functions that reach the most
    /// of the codebase, biased towards ones with names that look like entry
    /// points. Being handed a starting point is the single biggest difference
    /// between bouncing off a project and getting into it.
    func startingPoints(limit: Int = 8) -> [Int] {
        guard let graph else { return [] }
        let interesting = graph.nodes.indices.filter { idx in
            let n = graph.nodes[idx]
            guard !n.isExternal, n.kind.isCallable, n.fileIndex >= 0 else { return false }
            let path = graph.files[n.fileIndex].lowercased()
            if path.contains("test") || path.contains("spec") { return false }
            return n.fanOut >= 2
        }
        return interesting
            .sorted { a, b in
                let na = graph.nodes[a], nb = graph.nodes[b]
                let sa = score(na), sb = score(nb)
                if sa != sb { return sa > sb }
                return na.fanOut > nb.fanOut
            }
            .prefix(limit)
            .map { $0 }
    }

    private func score(_ node: GraphNode) -> Int {
        var s = node.fanOut
        let entryish = ["main", "run", "start", "app", "init", "serve", "handle", "execute"]
        if entryish.contains(node.name.lowercased()) { s += 40 }
        if node.fanIn == 0 { s += 12 }          // nothing above it: a top of the tree
        if node.span > 12 { s += 4 }
        return s
    }

    var searchResults: [Int] {
        guard let graph, !searchText.isEmpty else { return [] }
        let needle = searchText.lowercased()
        return graph.nodes.indices
            .filter { graph.nodes[$0].name.lowercased().contains(needle)
                   || (graph.nodes[$0].container?.lowercased().contains(needle) ?? false) }
            .sorted { a, b in
                let na = graph.nodes[a].name.lowercased()
                let nb = graph.nodes[b].name.lowercased()
                if (na == needle) != (nb == needle) { return na == needle }
                if na.hasPrefix(needle) != nb.hasPrefix(needle) { return na.hasPrefix(needle) }
                return graph.nodes[a].fanIn > graph.nodes[b].fanIn
            }
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
