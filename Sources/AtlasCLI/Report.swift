import Foundation

/// The wire format between the engine and a user interface.
///
/// Written out as explicit DTOs rather than by making the graph types
/// `Codable`. Two reasons: the analysis types stay free to change shape
/// without silently breaking a shipped UI, and the format can say things the
/// in-memory model leaves implicit — a localised issue title, a difficulty
/// band, a colour-bearing layer — so the Windows client does not have to
/// re-derive them.
///
/// Indices are the vocabulary here, exactly as they are in the graph. A
/// symbol's `file` indexes `files`; a call's `f`/`t` index `symbols`; a
/// diagram card's `node` indexes `diagram.nodes`. Nothing is looked up by
/// string.
///
/// Optionals are **omitted rather than written as `null`** — that is
/// `JSONEncoder`'s default, and it keeps a large report meaningfully
/// smaller. A missing `container`, `symbol`, `from`, `diagram` or `drift`
/// means absent, and a client should read them as nullable.
struct Report: Encodable {

    /// Bumped when a field changes meaning or disappears, so a mismatched
    /// client can say so instead of misreading the numbers.
    static let schema = 2

    var schema: Int = Report.schema
    var project: Project
    var files: [FileEntry]
    var symbols: [SymbolEntry]
    var calls: [Call]
    var fileEdges: [FileEdge]
    var hubs: [Int]
    var map: Map?
    var issues: [IssueEntry]
    var route: [RouteStep]
    var drift: DriftReport?

    // MARK: - Project

    struct Project: Encodable {
        var name: String
        var root: String
        var kind: String            // ProjectKind.rawValue — stable key
        var kindLabel: String       // the same, in the requested language
        var kindExplanation: String // what that kind of thing *is*, in prose
        var fileCount: Int
        var lineCount: Int
        var symbolCount: Int
        var callCount: Int
        var parseSeconds: Double
        var analysedAt: Date
        var languages: [LanguageCount]
    }

    struct LanguageCount: Encodable {
        var id: String              // Language.rawValue
        var name: String            // Language.displayName
        var files: Int
    }

    // MARK: - Files and symbols

    struct FileEntry: Encodable {
        var path: String            // relative to root, always `/`-separated
        var name: String
        var directory: String
        var language: String
    }

    struct SymbolEntry: Encodable {
        var name: String
        var container: String?
        var display: String
        var kind: String            // SymbolKind.rawValue
        var language: String
        var file: Int               // index into `files`
        var line: Int
        var endLine: Int
        var fanIn: Int
        var fanOut: Int
        var external: Bool
        var branches: Int
        var nesting: Int
        var difficulty: String      // easy | moderate | hard
    }

    /// One call edge. Short keys because a large project has tens of
    /// thousands of these and they dominate the file size.
    struct Call: Encodable {
        var f: Int                  // caller, index into `symbols`
        var t: Int                  // callee
        var n: Int                  // distinct call sites
    }

    /// A file-to-file dependency taken from imports rather than calls.
    struct FileEdge: Encodable {
        var f: Int                  // index into `files`
        var t: Int
    }

    // MARK: - Map

    /// The call ladder, already placed.
    ///
    /// The layout travels with the data because it is deliberate — depth by
    /// longest path, then barycentre sweeps to reduce crossings — and because
    /// the picture is the product. Two clients each deriving their own would
    /// draw the same repository two different ways. Coordinates are absolute
    /// on a canvas of `canvas` size, so a client only pans and zooms.
    struct Map: Encodable {
        var canvas: Size
        var nodes: [Node]
        var boxes: [Box]
        /// Node indices per column, in the order they are stacked.
        var columns: [[Int]]
        var edges: [Edge]
        var cycles: [[Int]]         // indices into `nodes`

        struct Size: Encodable { var w: Double; var h: Double }

        struct Node: Encodable {
            var file: Int           // index into `files`
            var path: String
            var name: String
            var layer: String       // Layer.rawValue — drives the district rule
            var layerLabel: String
            var language: String
            var symbols: [Int]      // indices into `symbols`, most connected first
            var symbolCount: Int
            var lines: Int
            var fanIn: Int
            var fanOut: Int
        }

        struct Box: Encodable {
            var node: Int           // index into `map.nodes`
            var x: Double
            var y: Double
            var w: Double
            var h: Double
            var column: Int
            var row: Int
        }

        /// A file-to-file dependency, weighted by how many call sites back it.
        struct Edge: Encodable {
            var f: Int              // index into `map.nodes`
            var t: Int
            var weight: Int
        }
    }

    // MARK: - Findings

    struct IssueEntry: Encodable {
        var id: Int
        var kind: String            // Issue.Kind.rawValue
        var severity: String        // low | medium | high
        var title: String
        var subject: String
        var detail: String
        var advice: String
        var file: String
        var line: Int
        var symbol: Int?            // index into `symbols`, when there is one
    }

    struct RouteStep: Encodable {
        var symbol: Int             // index into `symbols`
        var from: Int?              // the step that calls it
        /// How many symbols this step can reach. Computed here because it is
        /// a graph walk, and a client that repeated it would be reimplementing
        /// the analysis it was given.
        var reach: Int
    }

    struct DriftReport: Encodable {
        var previousScan: Date?
        var entries: [Entry]

        struct Entry: Encodable {
            var kind: String        // Drift.Kind.rawValue
            var subject: String
            var delta: Int
            var detail: String
            /// The change written out as a sentence. Composed here because the
            /// wording depends on the kind *and* the numbers, which no simple
            /// template survives — and because an entry can have no subject at
            /// all, where the sentence is the whole row.
            var note: String
            var regression: Bool
            var improvement: Bool
        }
    }
}

// MARK: - Building

extension Report {

    /// Assembles the report from a finished analysis.
    static func build(graph: CodeGraph,
                      fileGraph: FileGraph,
                      layout: LadderLayout?,
                      issues: [Issue],
                      route: Route,
                      kind: ProjectKind,
                      drift: Drift?,
                      language: AppLanguage) -> Report {

        let languages = graph.languageCounts
            .sorted { $0.value > $1.value }
            .map { LanguageCount(id: $0.key.rawValue,
                                 name: $0.key.displayName,
                                 files: $0.value) }

        let project = Project(
            name: graph.projectName,
            root: graph.rootPath,
            kind: kind.rawValue,
            kindLabel: language == .uz ? kind.uz : kind.en,
            kindExplanation: kind.explanation(language: language),
            fileCount: graph.files.count,
            lineCount: graph.totalLines,
            symbolCount: graph.nodes.count,
            callCount: graph.edges.count,
            parseSeconds: graph.parseSeconds,
            analysedAt: Date(),
            languages: languages)

        let files = graph.files.map {
            FileEntry(path: $0,
                      name: P.lastComponent($0),
                      directory: P.deletingLastComponent($0),
                      language: Language.detect(path: $0)?.rawValue ?? "")
        }

        let symbols = graph.nodes.map { node in
            SymbolEntry(name: node.name,
                        container: node.container,
                        display: node.displayName,
                        kind: node.kind.rawValue,
                        language: node.language.rawValue,
                        file: node.fileIndex,
                        line: node.line,
                        endLine: node.endLine,
                        fanIn: node.fanIn,
                        fanOut: node.fanOut,
                        external: node.isExternal,
                        branches: node.branches,
                        nesting: node.maxNesting,
                        difficulty: label(node.difficulty))
        }

        let calls = graph.edges.map { Call(f: $0.from, t: $0.to, n: $0.count) }
        let fileEdges = graph.fileReferences.map { FileEdge(f: $0.from, t: $0.to) }

        let issueEntries = issues.map {
            IssueEntry(id: $0.id,
                       kind: $0.kind.rawValue,
                       severity: label($0.severity),
                       title: $0.title(language),
                       subject: $0.subject,
                       detail: $0.detail,
                       advice: $0.advice(language),
                       file: $0.file,
                       line: $0.line,
                       symbol: $0.symbolID)
        }

        let steps = route.steps.map {
            RouteStep(symbol: $0.nodeID, from: $0.reachedFrom,
                      reach: graph.reach(of: $0.nodeID))
        }

        let words = L10n(language: language)
        let driftReport = drift.map { d in
            DriftReport(previousScan: d.previousScan,
                        entries: d.entries.map {
                            DriftReport.Entry(kind: $0.kind.rawValue,
                                              subject: $0.subject,
                                              delta: $0.delta,
                                              detail: $0.detail,
                                              note: words.driftNote($0),
                                              regression: $0.isRegression,
                                              improvement: $0.isImprovement)
                        })
        }

        return Report(project: project,
                      files: files,
                      symbols: symbols,
                      calls: calls,
                      fileEdges: fileEdges,
                      hubs: graph.hubs(limit: 12),
                      map: layout.map { map(fileGraph: fileGraph, layout: $0,
                                            language: language) },
                      issues: issueEntries,
                      route: steps,
                      drift: driftReport)
    }

    private static func map(fileGraph: FileGraph,
                            layout: LadderLayout,
                            language: AppLanguage) -> Map {
        let nodes = fileGraph.nodes.map { node in
            Map.Node(file: node.id,
                     path: node.path,
                     name: node.name,
                     layer: node.layer.rawValue,
                     layerLabel: language == .uz ? node.layer.uz : node.layer.en,
                     language: node.language.rawValue,
                     symbols: node.symbols,
                     symbolCount: node.symbolCount,
                     lines: node.lines,
                     fanIn: node.fanIn,
                     fanOut: node.fanOut)
        }

        // Sorted by node index: `frame` is a dictionary, and its order is not
        // the same twice in a row.
        let boxes = layout.frame.keys.sorted().compactMap { index -> Map.Box? in
            guard let rect = layout.frame[index] else { return nil }
            let column = layout.columns.firstIndex { $0.contains(index) } ?? 0
            let row = layout.columns[column].firstIndex(of: index) ?? 0
            return Map.Box(node: index,
                           x: Double(rect.origin.x), y: Double(rect.origin.y),
                           w: Double(rect.size.width), h: Double(rect.size.height),
                           column: column, row: row)
        }

        return Map(canvas: Map.Size(w: Double(layout.canvas.width),
                                    h: Double(layout.canvas.height)),
                   nodes: nodes,
                   boxes: boxes,
                   columns: layout.columns,
                   edges: fileGraph.edges.map {
                       Map.Edge(f: $0.from, t: $0.to, weight: $0.weight)
                   },
                   cycles: fileGraph.cycles)
    }

    // Both enums are ordered rather than named in the model, because ordering
    // is what the app sorts by. The wire format spells them out.
    private static func label(_ d: GraphNode.Difficulty) -> String {
        switch d {
        case .easy: return "easy"
        case .moderate: return "moderate"
        case .hard: return "hard"
        }
    }

    private static func label(_ s: Issue.Severity) -> String {
        switch s {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }
}
