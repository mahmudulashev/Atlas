import Foundation

/// An ordered path through a codebase for someone reading it the first time.
///
/// The old sidebar handed the reader a ranked list and left the ordering to
/// them. A list is not a route: it says what matters, never what to read second.
/// This walks the call graph the way execution does — from an entry point
/// downward — so each step is reached by the one before it, and the reader is
/// never asked to jump somewhere with no path from where they have been.
struct Route {

    struct Step {
        let nodeID: Int
        let reachedFrom: Int?      // the previous step that calls this one
    }

    let steps: [Step]

    var nodeIDs: [Int] { steps.map(\.nodeID) }
    var isEmpty: Bool { steps.isEmpty }

    // MARK: - Construction

    static func build(from graph: CodeGraph, maxSteps: Int = 6) -> Route {
        guard let start = pickEntryPoint(in: graph) else { return Route(steps: []) }

        var steps: [Step] = [Step(nodeID: start, reachedFrom: nil)]
        var visited: Set<Int> = [start]
        var current = start

        while steps.count < maxSteps {
            let isLast = steps.count == maxSteps - 1
            let candidates = graph.outgoing[current].filter {
                !visited.contains($0) && isReadable($0, in: graph)
                    && (isLast || graph.nodes[$0].fanOut > 0)   // don't stop early on a dead end
            }
            guard let next = candidates.max(by: {
                stepScore($0, from: current, in: graph) < stepScore($1, from: current, in: graph)
            }) else { break }

            steps.append(Step(nodeID: next, reachedFrom: current))
            visited.insert(next)
            current = next
        }

        // A one- or two-step route is not a route. Widen out from the entry
        // point so the reader still has somewhere to go.
        if steps.count < 4 {
            let siblings = graph.outgoing[start]
                .filter { !visited.contains($0) && isReadable($0, in: graph) }
                .sorted { stepScore($0, from: start, in: graph) > stepScore($1, from: start, in: graph) }
            for id in siblings where steps.count < maxSteps {
                steps.append(Step(nodeID: id, reachedFrom: start))
                visited.insert(id)
            }
        }

        return Route(steps: steps)
    }

    // MARK: - Filtering

    /// Tests, examples and benchmarks are real code but they are not the
    /// program. A first read should stay on the path the program itself takes.
    private static func isReadable(_ id: Int, in graph: CodeGraph) -> Bool {
        let node = graph.nodes[id]
        guard !node.isExternal, node.kind.isCallable, node.fileIndex >= 0,
              node.fileIndex < graph.files.count else { return false }
        let path = graph.files[node.fileIndex].lowercased()
        for marker in ["test", "spec", "example", "sample", "benchmark", "demo",
                       "fixture", "mock", "vendor", "third_party", "script"]
        where path.contains(marker) { return false }
        return true
    }

    /// Directories that hold the actual program rather than its surroundings.
    private static func isCoreDirectory(_ id: Int, in graph: CodeGraph) -> Bool {
        let node = graph.nodes[id]
        guard node.fileIndex >= 0, node.fileIndex < graph.files.count else { return false }
        let path = graph.files[node.fileIndex].lowercased()
        return path.hasPrefix("src/") || path.hasPrefix("lib/") || path.hasPrefix("app/")
            || path.hasPrefix("source/") || path.hasPrefix("internal/") || !path.contains("/")
    }

    private static func directory(_ id: Int, in graph: CodeGraph) -> String {
        guard id >= 0, graph.nodes[id].fileIndex >= 0,
              graph.nodes[id].fileIndex < graph.files.count else { return "" }
        return P.deletingLastComponent(graph.files[graph.nodes[id].fileIndex])
    }

    // MARK: - Scoring

    /// Choosing the next step is a balance between *leading somewhere* and
    /// *being worth reading*. Both halves are capped: without a cap a single
    /// enormous function or a universally-used helper such as `strlen` wins
    /// every comparison and the route collapses onto it.
    private static func stepScore(_ id: Int, from previous: Int, in graph: CodeGraph) -> Int {
        let node = graph.nodes[id]
        var score = min(node.fanOut, 12) * 4 + min(node.fanIn, 6)

        if node.span >= 6 { score += 6 } else { score -= 10 }
        if node.fanOut == 0 { score -= 25 }
        if node.fanIn > 40 { score -= 30 }               // a shared utility, not a stage
        if isCoreDirectory(id, in: graph) { score += 12 }
        if directory(id, in: graph) == directory(previous, in: graph) { score += 8 }
        if node.kind == .initializer { score -= 4 }
        return score
    }

    /// Reach is used only to break ties between plausible entry points, and is
    /// capped for the same reason: the biggest function in a project is rarely
    /// where a program starts.
    private static func reach(of id: Int, in graph: CodeGraph) -> Int {
        let node = graph.nodes[id]
        var score = min(node.fanOut, 10) * 2
        for callee in graph.outgoing[id].prefix(12) where !graph.nodes[callee].isExternal {
            score += min(graph.nodes[callee].fanOut, 4)
        }
        return min(score, 40)
    }

    /// Where a program actually begins, as far as the graph can tell.
    ///
    /// Being *named* like an entry point outweighs everything else, because a
    /// function called `main` is a far stronger signal than any structural
    /// measure — and structure alone will happily nominate the largest internal
    /// routine in the project, which is the worst possible place to start.
    private static func pickEntryPoint(in graph: CodeGraph) -> Int? {
        let entryNames: Set<String> = ["main", "run", "start", "serve", "app", "application",
                                       "wsgi_app", "handle", "execute", "launch", "boot",
                                       "createapp", "createserver", "listen", "dispatch"]
        let candidates = graph.nodes.indices.filter {
            isReadable($0, in: graph) && graph.nodes[$0].fanOut >= 1
        }
        guard !candidates.isEmpty else { return nil }
        return candidates.max { score($0) < score($1) }

        func score(_ id: Int) -> Int {
            let node = graph.nodes[id]
            var s = reach(of: id, in: graph)
            if entryNames.contains(node.name.lowercased()) { s += 120 }
            if node.fanIn == 0 { s += 45 }               // nothing above it
            if node.fanIn > 20 { s -= 50 }               // a destination, not a start
            if isCoreDirectory(id, in: graph) { s += 20 }
            if node.span < 4 { s -= 15 }
            return s
        }
    }
}

/// What kind of program this is, in one word the reader already knows.
///
/// Classified from evidence the analyser already has — the names of the most
/// connected symbols and the shape of the directory tree — with the on-device
/// model consulted only to choose among these fixed options. As with
/// `CodeSummary`, the wording the reader sees is written here, which is what
/// makes a genuine Uzbek answer possible.
enum ProjectKind: String, CaseIterable, Sendable {
    case webFramework = "web framework"
    case webApp = "web application"
    case commandLineTool = "command line tool"
    case library = "library"
    case desktopApp = "desktop application"
    case mobileApp = "mobile application"
    case game = "game"
    case languageTool = "compiler or parser"
    case dataTool = "data or machine learning tool"
    case database = "database or storage engine"
    case networkService = "server or network service"

    var uz: String {
        switch self {
        case .webFramework:    return "veb-freymvork"
        case .webApp:          return "veb-ilova"
        case .commandLineTool: return "terminal dasturi"
        case .library:         return "kutubxona"
        case .desktopApp:      return "kompyuter ilovasi"
        case .mobileApp:       return "telefon ilovasi"
        case .game:            return "oʻyin"
        case .languageTool:    return "kompilyator yoki tahlilchi"
        case .dataTool:        return "maʼlumot va sunʼiy intellekt vositasi"
        case .database:        return "maʼlumotlar bazasi"
        case .networkService:  return "server dasturi"
        }
    }

    var en: String {
        switch self {
        case .webFramework:    return "web framework"
        case .webApp:          return "web application"
        case .commandLineTool: return "command-line tool"
        case .library:         return "library"
        case .desktopApp:      return "desktop application"
        case .mobileApp:       return "mobile application"
        case .game:            return "game"
        case .languageTool:    return "compiler or parser"
        case .dataTool:        return "data and machine-learning tool"
        case .database:        return "database engine"
        case .networkService:  return "server"
        }
    }

    /// A sentence explaining the category itself — a beginner may not know what
    /// a framework or a parser is either.
    func explanation(language: AppLanguage) -> String {
        switch (self, language) {
        case (.webFramework, .uz):    return "Brauzerdan kelgan soʻrovni qabul qilib javob qaytaradigan dastur yozish uchun asos."
        case (.webFramework, .en):    return "A foundation for writing programs that answer requests coming from a browser."
        case (.webApp, .uz):          return "Brauzerda ochiladigan, foydalanuvchi bilan ishlaydigan dastur."
        case (.webApp, .en):          return "A program people use through a browser."
        case (.commandLineTool, .uz): return "Terminalda buyruq yozib ishlatiladigan dastur — oynasi yoʻq."
        case (.commandLineTool, .en): return "A program run by typing commands in a terminal — no window."
        case (.library, .uz):         return "Oʻzi ishlamaydi. Boshqa dasturlar undan tayyor funksiyalarni olib ishlatadi."
        case (.library, .en):         return "It doesn't run on its own — other programs borrow its functions."
        case (.desktopApp, .uz):      return "Kompyuterda oʻrnatilib, oynasi bilan ishlaydigan dastur."
        case (.desktopApp, .en):      return "An installed program with its own window."
        case (.mobileApp, .uz):       return "Telefon yoki planshet uchun yozilgan ilova."
        case (.mobileApp, .en):       return "An app written for a phone or tablet."
        case (.game, .uz):            return "Oʻyin — grafika chizadi va oʻyinchi harakatlariga javob beradi."
        case (.game, .en):            return "A game — it draws graphics and responds to player input."
        case (.languageTool, .uz):    return "Kodni oʻqib tushunadigan dastur: matnni boʻlaklarga ajratib, maʼnosini aniqlaydi."
        case (.languageTool, .en):    return "A program that reads code: it splits text into pieces and works out their meaning."
        case (.dataTool, .uz):        return "Katta maʼlumotlarni qayta ishlaydigan yoki model oʻrgatadigan dastur."
        case (.dataTool, .en):        return "A program that processes large amounts of data or trains models."
        case (.database, .uz):        return "Maʼlumotni saqlab, tez topib beradigan dastur."
        case (.database, .en):        return "A program that stores data and finds it again quickly."
        case (.networkService, .uz):  return "Tarmoq orqali kelgan soʻrovlarga javob beradigan dastur."
        case (.networkService, .en):  return "A program that answers requests arriving over a network."
        }
    }

    /// Evidence-based guess, used when the model is unavailable and as a prior.
    static func heuristic(for graph: CodeGraph) -> ProjectKind {
        let haystack = (graph.files.prefix(400).joined(separator: " ")
                        + " " + graph.hubs(limit: 30).map { graph.nodes[$0].name }.joined(separator: " "))
            .lowercased()

        func hits(_ words: [String]) -> Int {
            words.reduce(0) { $0 + (haystack.contains($1) ? 1 : 0) }
        }

        var scores: [(ProjectKind, Int)] = [
            (.webFramework,    hits(["route", "request", "response", "wsgi", "middleware", "blueprint"])),
            (.languageTool,    hits(["token", "lexer", "parser", "ast", "compile", "grammar"])),
            (.database,        hits(["btree", "wal", "index", "storage", "query", "transaction"])),
            (.game,            hits(["render", "sprite", "shader", "physics", "collision", "entity"])),
            (.dataTool,        hits(["tensor", "train", "model", "dataset", "gradient", "layer"])),
            (.commandLineTool, hits(["argv", "flag", "command", "usage", "stdin", "cli"])),
            (.desktopApp,      hits(["window", "view", "button", "menu", "swiftui", "appkit"])),
            (.networkService,  hits(["socket", "server", "listen", "connection", "protocol", "client"])),
        ]
        scores.sort { $0.1 > $1.1 }
        if let best = scores.first, best.1 >= 2 { return best.0 }
        return .library
    }
}
