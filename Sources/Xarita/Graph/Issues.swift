import Foundation

/// Something in the codebase worth a second look.
///
/// Every finding here is derived from the graph the analyser already built, so
/// each one can point at a real file and line. Nothing is guessed by a language
/// model, and nothing is reported that the tool cannot show you.
struct Issue: Identifiable, Sendable {
    enum Kind: String, Sendable {
        case cycle              // files that depend on each other in a loop
        case unreachable        // nothing calls it
        case oversizedFile      // too much in one place
        case complexFunction    // too many paths, too deeply nested
        case godFunction        // half the codebase depends on it
        case layerViolation     // a call that skips or reverses the architecture
    }

    enum Severity: Int, Comparable, Sendable {
        case low, medium, high
        static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
    }

    let id: Int
    let kind: Kind
    let severity: Severity
    let subject: String          // what it is about
    let detail: String           // the measurement behind it
    let file: String
    let line: Int
    let symbolID: Int?           // jump target, when there is one

    // MARK: - Wording

    func title(_ language: AppLanguage) -> String {
        switch (kind, language) {
        case (.cycle, .uz):            return "Aylanma bogʻliqlik"
        case (.cycle, .en):            return "Dependency cycle"
        case (.unreachable, .uz):      return "Hech kim chaqirmaydi"
        case (.unreachable, .en):      return "Nothing calls this"
        case (.oversizedFile, .uz):    return "Fayl juda katta"
        case (.oversizedFile, .en):    return "Oversized file"
        case (.complexFunction, .uz):  return "Funksiya juda murakkab"
        case (.complexFunction, .en):  return "Complex function"
        case (.godFunction, .uz):      return "Hamma unga bogʻliq"
        case (.godFunction, .en):      return "Everything depends on this"
        case (.layerViolation, .uz):   return "Qatlam buzilgan"
        case (.layerViolation, .en):   return "Layering violation"
        }
    }

    /// Why it matters — the part a beginner cannot infer from the label.
    func advice(_ language: AppLanguage) -> String {
        switch (kind, language) {
        case (.cycle, .uz):
            return "Ikki fayl bir-birini chaqiradi. Biriga tegsang, ikkinchisi ham buziladi — ularni alohida sinash ham qiyin."
        case (.cycle, .en):
            return "Two files call each other, so neither can be changed or tested on its own."
        case (.unreachable, .uz):
            return "Loyihada uni chaqiradigan joy topilmadi. Framework orqali chaqirilayotgan boʻlishi mumkin — oʻchirishdan oldin tekshir."
        case (.unreachable, .en):
            return "No call to it was found. A framework may invoke it invisibly, so check before deleting."
        case (.oversizedFile, .uz):
            return "Bitta faylda juda koʻp narsa bor. Boʻlib yuborilsa, kerakli joyni topish osonlashadi."
        case (.oversizedFile, .en):
            return "Too much lives in one file. Splitting it makes things easier to find."
        case (.complexFunction, .uz):
            return "Koʻp shart va chuqur ichma-ichlik. Bunday funksiyada xato yashirinishi oson, sinash esa qiyin."
        case (.complexFunction, .en):
            return "Many branches and deep nesting. Bugs hide easily here and tests are hard to write."
        case (.godFunction, .uz):
            return "Juda koʻp joy shunga tayanadi. Oʻzgartirsang taʼsiri keng boʻladi — ehtiyot boʻl."
        case (.godFunction, .en):
            return "A great deal leans on this. Any change here reaches a long way."
        case (.layerViolation, .uz):
            return "Interfeys fayli maʼlumot qatlamiga toʻgʻridan-toʻgʻri murojaat qilyapti, oradagi mantiqni chetlab oʻtib."
        case (.layerViolation, .en):
            return "An interface file reaches straight into storage, skipping the logic in between."
        }
    }
}

enum IssueFinder {

    /// Thresholds are deliberately generous. A report that flags everything is
    /// ignored, and the point is to surface the handful of places actually
    /// worth a developer's attention.
    struct Limits {
        var maxFunctionsPerFile = 45
        var maxLinesPerFile = 900
        var complexityScore = 22
        var godFunctionCallers = 45

        /// How many findings of one kind are worth listing.
        var maxPerKind = 12
    }

    static func find(graph: CodeGraph, fileGraph: FileGraph,
                     limits: Limits = Limits()) -> [Issue] {
        var issues: [Issue] = []
        var id = 0
        func next() -> Int { defer { id += 1 }; return id }

        // ---- Cycles ----
        for cycle in fileGraph.cycles.prefix(6) {
            let names = cycle.prefix(4).map { fileGraph.nodes[$0].name }
            let first = fileGraph.nodes[cycle[0]]
            issues.append(Issue(id: next(), kind: .cycle,
                                severity: cycle.count > 3 ? .high : .medium,
                                subject: names.joined(separator: " → "),
                                detail: "\(cycle.count)",
                                file: first.path, line: 1, symbolID: first.symbols.first))
        }

        // ---- Files that have grown too big ----
        for node in fileGraph.nodes {
            if node.symbolCount > limits.maxFunctionsPerFile {
                issues.append(Issue(id: next(), kind: .oversizedFile,
                                    severity: node.symbolCount > limits.maxFunctionsPerFile * 2
                                              ? .high : .medium,
                                    subject: node.name,
                                    detail: "\(node.symbolCount)",
                                    file: node.path, line: 1, symbolID: node.symbols.first))
            } else if node.lines > limits.maxLinesPerFile {
                issues.append(Issue(id: next(), kind: .oversizedFile, severity: .low,
                                    subject: node.name,
                                    detail: "\(node.lines)",
                                    file: node.path, line: 1, symbolID: node.symbols.first))
            }
        }

        // ---- Functions that are hard to read ----
        for node in graph.nodes where !node.isExternal && node.kind.isCallable {
            guard node.difficultyScore >= limits.complexityScore else { continue }
            let path = node.fileIndex >= 0 && node.fileIndex < graph.files.count
                ? graph.files[node.fileIndex] : ""
            guard !path.lowercased().contains("test") else { continue }
            issues.append(Issue(id: next(), kind: .complexFunction,
                                severity: node.difficultyScore >= limits.complexityScore * 2
                                          ? .high : .medium,
                                subject: node.displayName,
                                detail: "\(node.branches) · \(node.maxNesting) · \(node.span)",
                                file: path, line: node.line, symbolID: node.id))
        }

        // ---- Symbols the whole project leans on ----
        for node in graph.nodes where !node.isExternal && node.fanIn >= limits.godFunctionCallers {
            let path = node.fileIndex >= 0 && node.fileIndex < graph.files.count
                ? graph.files[node.fileIndex] : ""
            issues.append(Issue(id: next(), kind: .godFunction, severity: .low,
                                subject: node.displayName,
                                detail: "\(node.fanIn)",
                                file: path, line: node.line, symbolID: node.id))
        }

        // ---- Architecture shortcuts ----
        // An interface file calling storage directly means the logic layer has
        // been bypassed — the thing that quietly turns a layered project into
        // one where nothing can move.
        for edge in fileGraph.edges {
            let from = fileGraph.nodes[edge.from]
            let to = fileGraph.nodes[edge.to]
            guard from.layer == .ui, to.layer == .data else { continue }
            issues.append(Issue(id: next(), kind: .layerViolation, severity: .medium,
                                subject: "\(from.name) → \(to.name)",
                                detail: "\(edge.weight)",
                                file: from.path, line: 1, symbolID: from.symbols.first))
        }

        // ---- Code nothing reaches ----
        for symbolID in graph.unreachable.prefix(40) {
            let node = graph.nodes[symbolID]
            guard node.span >= 4 else { continue }          // one-liners aren't worth reporting
            let path = node.fileIndex >= 0 && node.fileIndex < graph.files.count
                ? graph.files[node.fileIndex] : ""
            issues.append(Issue(id: next(), kind: .unreachable, severity: .low,
                                subject: node.displayName,
                                detail: "\(node.span)",
                                file: path, line: node.line, symbolID: node.id))
        }

        // A report of seven hundred findings is a report nobody opens. Redis
        // alone yields over five hundred complex functions — all real, none
        // useful as a list. Keeping the worst of each kind turns the output
        // back into something a person can act on in an afternoon.
        var perKind: [Issue.Kind: [Issue]] = [:]
        for issue in issues { perKind[issue.kind, default: []].append(issue) }

        var trimmed: [Issue] = []
        for (kind, group) in perKind {
            let ranked = group.sorted { a, b in
                if a.severity != b.severity { return a.severity > b.severity }
                return (Int(a.detail.prefix(while: \.isNumber)) ?? 0)
                     > (Int(b.detail.prefix(while: \.isNumber)) ?? 0)
            }
            trimmed.append(contentsOf: ranked.prefix(limits.maxPerKind))
            _ = kind
        }

        return trimmed.sorted { a, b in
            if a.severity != b.severity { return a.severity > b.severity }
            return a.kind.rawValue < b.kind.rawValue
        }
    }
}
