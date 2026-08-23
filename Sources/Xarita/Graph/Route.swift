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
            let candidates = graph.outgoing[current].filter { id in
                !visited.contains(id)
                    && !graph.nodes[id].isExternal
                    && graph.nodes[id].kind.isCallable
                    && graph.nodes[id].fileIndex >= 0
            }
            guard let next = candidates.max(by: { reach(of: $0, in: graph) < reach(of: $1, in: graph) })
            else { break }

            steps.append(Step(nodeID: next, reachedFrom: current))
            visited.insert(next)
            current = next
        }

        // A one-step route is not a route. Fall back to breadth at the entry
        // point so the reader still gets somewhere to go.
        if steps.count < 3 {
            let siblings = graph.outgoing[start]
                .filter { !visited.contains($0) && !graph.nodes[$0].isExternal
                          && graph.nodes[$0].kind.isCallable && graph.nodes[$0].fileIndex >= 0 }
                .sorted { reach(of: $0, in: graph) > reach(of: $1, in: graph) }
            for id in siblings where steps.count < maxSteps {
                steps.append(Step(nodeID: id, reachedFrom: start))
                visited.insert(id)
            }
        }

        return Route(steps: steps)
    }

    /// How much of the codebase a step opens up: its own connections plus, at a
    /// discount, those of everything it calls. Preferring reach over raw
    /// popularity keeps the route on the spine of the program instead of
    /// detouring into a heavily-used leaf like a string helper.
    private static func reach(of id: Int, in graph: CodeGraph) -> Int {
        let node = graph.nodes[id]
        var score = node.fanOut * 3 + node.fanIn
        for callee in graph.outgoing[id] where !graph.nodes[callee].isExternal {
            score += graph.nodes[callee].fanOut
        }
        if node.span >= 6  { score += 4 }        // trivial one-liners teach little
        if node.span <= 2  { score -= 8 }
        if node.kind == .initializer { score -= 3 }
        return score
    }

    /// Where a program actually begins, as far as the graph can tell.
    private static func pickEntryPoint(in graph: CodeGraph) -> Int? {
        let entryNames: Set<String> = ["main", "run", "start", "serve", "app", "application",
                                       "wsgi_app", "handle", "execute", "launch", "boot", "init"]
        let candidates = graph.nodes.indices.filter { id in
            let n = graph.nodes[id]
            guard !n.isExternal, n.kind.isCallable, n.fileIndex >= 0, n.fanOut >= 1 else { return false }
            let path = graph.files[n.fileIndex].lowercased()
            return !path.contains("test") && !path.contains("spec")
                && !path.contains("example") && !path.contains("benchmark")
        }
        guard !candidates.isEmpty else { return nil }

        return candidates.max { a, b in score(a) < score(b) }

        func score(_ id: Int) -> Int {
            let n = graph.nodes[id]
            var s = reach(of: id, in: graph)
            if entryNames.contains(n.name.lowercased()) { s += 60 }
            if n.fanIn == 0 { s += 25 }              // nothing above it: a true top
            if n.fanIn > 20 { s -= 20 }              // a hub is a destination, not a start
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
