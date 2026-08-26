import Foundation

/// What a declaration does, said from the graph alone.
///
/// No model, no network, nothing that can be unavailable — every machine can
/// produce this, which is why it is what the panel always shows. On macOS an
/// on-device model may add a better paragraph above it; this is the floor,
/// not the fallback.
enum Explanation {

    static func fromGraph(node: GraphNode,
                          graph: CodeGraph,
                          t: L10n) -> String {
        var parts: [String] = []
        let (callers, callees) = graph.neighbours(of: node.id)

        let kind = t.kindName(node.kind)
        parts.append(t.language == .uz
            ? "`\(node.name)` — \(kind), \(node.span) qator."
            : "`\(node.name)` is a \(kind), \(node.span) lines long.")

        if callers.isEmpty {
            parts.append(t.language == .uz
                ? "Loyihada uni hech kim chaqirmaydi — bu kirish nuqtasi yoki framework orqali chaqiriladigan kod boʻlishi mumkin."
                : "Nothing in this project calls it — it may be an entry point, or invoked by a framework.")
        } else {
            let names = callers.prefix(3).map { graph.nodes[$0].displayName }
            let more = callers.count > 3 ? (t.language == .uz ? " va yana \(callers.count - 3) ta" : " and \(callers.count - 3) more") : ""
            parts.append(t.language == .uz
                ? "Uni \(callers.count) ta joy chaqiradi: \(names.joined(separator: ", "))\(more)."
                : "It is called from \(callers.count) place\(callers.count == 1 ? "" : "s"): \(names.joined(separator: ", "))\(more).")
        }

        if callees.isEmpty {
            parts.append(t.language == .uz
                ? "Oʻzi boshqa funksiyalarni chaqirmaydi."
                : "It calls nothing else.")
        } else {
            let names = callees.prefix(3).map { graph.nodes[$0].displayName }
            let more = callees.count > 3 ? (t.language == .uz ? " va yana \(callees.count - 3) ta" : " and \(callees.count - 3) more") : ""
            parts.append(t.language == .uz
                ? "Oʻzi \(callees.count) ta funksiyani chaqiradi: \(names.joined(separator: ", "))\(more)."
                : "It calls \(callees.count) other\(callees.count == 1 ? "" : "s"): \(names.joined(separator: ", "))\(more).")
        }

        if node.fanIn >= 8 {
            parts.append(t.language == .uz
                ? "Koʻp chaqirilgani uchun bu markaziy funksiya — oʻzgartirsang, taʼsiri keng boʻladi."
                : "Its high number of callers makes it a hub — changing it has wide reach.")
        }

        return parts.joined(separator: " ")
    }
}
