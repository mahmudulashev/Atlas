import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Plain-language explanations of a declaration.
///
/// Two tiers, and the app is fully usable on the lower one:
///
/// 1. **Static** — assembled from the graph itself. Deterministic, instant, and
///    available on every Mac the app runs on.
/// 2. **On-device model** — Apple's `FoundationModels`, used when the machine
///    has Apple Intelligence enabled. Nothing leaves the Mac, and nothing is
///    downloaded by us; the model ships with the OS.
///
/// The model is weak-linked and every use sits behind an availability check, so
/// the same binary runs on macOS 14 without it.
@MainActor
final class Explainer: ObservableObject {

    enum ModelState: Equatable {
        case checking
        case ready
        case needsAppleIntelligence
        case unsupportedOS
        case ineligibleDevice
        case modelDownloading

        var canGenerate: Bool { self == .ready }
    }

    @Published private(set) var modelState: ModelState = .checking
    @Published private(set) var streaming: String = ""
    @Published private(set) var isGenerating = false

    /// Explanations already produced, keyed by node id.
    @Published private(set) var cache: [Int: String] = [:]

    private var task: Task<Void, Never>?

    init() {
        refreshAvailability()
    }

    // MARK: - Availability

    func refreshAvailability() {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                modelState = .ready
            case .unavailable(let reason):
                switch reason {
                case .appleIntelligenceNotEnabled: modelState = .needsAppleIntelligence
                case .modelNotReady:               modelState = .modelDownloading
                case .deviceNotEligible:           modelState = .ineligibleDevice
                @unknown default:                  modelState = .needsAppleIntelligence
                }
            @unknown default:
                modelState = .needsAppleIntelligence
            }
        } else {
            modelState = .unsupportedOS
        }
        #else
        modelState = .unsupportedOS
        #endif
    }

    // MARK: - Static explanation

    /// Facts drawn straight from the graph. Always available, always true.
    static func staticExplanation(node: GraphNode,
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

    // MARK: - Model explanation

    func explain(node: GraphNode, graph: CodeGraph, source: String, language: AppLanguage) {
        task?.cancel()
        streaming = ""

        guard modelState.canGenerate else { return }

        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else { return }

        isGenerating = true
        let prompt = Self.buildPrompt(node: node, graph: graph, source: source, language: language)
        let instructions = Self.instructions(for: language)

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let session = LanguageModelSession(model: .default, instructions: instructions)
                let stream = session.streamResponse(to: prompt,
                                                    options: GenerationOptions(temperature: 0.3))
                for try await partial in stream {
                    if Task.isCancelled { return }
                    self.streaming = partial.content
                }
                self.cache[node.id] = self.streaming
            } catch {
                self.streaming = ""
            }
            self.isGenerating = false
        }
        #endif
    }

    func cancel() {
        task?.cancel()
        isGenerating = false
    }

    // MARK: - Prompting

    private static func instructions(for language: AppLanguage) -> String {
        switch language {
        case .en:
            return """
            You explain code to a junior developer who is reading an unfamiliar project.
            Rules:
            - At most 3 short sentences.
            - Say what the function does and why it exists, not how each line works.
            - Plain words. No jargon unless the code itself uses it.
            - Never invent behaviour you cannot see in the code.
            """
        case .uz:
            return """
            Siz notanish loyihani o'qiyotgan boshlovchi dasturchiga kodni tushuntirasiz.
            Qoidalar:
            - Ko'pi bilan 3 ta qisqa gap.
            - Funksiya nima qilishini va nima uchun kerakligini ayting, har bir qatorni emas.
            - Sodda so'zlar bilan yozing.
            - Kodda ko'rinmagan narsani o'ylab topmang.
            - Faqat o'zbek tilida javob bering.
            """
        }
    }

    /// Gives the model the declaration plus its immediate graph context — who
    /// calls it and what it calls — because that context is exactly what a
    /// reader lacks and what the analyser already knows.
    private static func buildPrompt(node: GraphNode,
                                    graph: CodeGraph,
                                    source: String,
                                    language: AppLanguage) -> String {
        let (callers, callees) = graph.neighbours(of: node.id)
        let callerNames = callers.prefix(5).map { graph.nodes[$0].displayName }.joined(separator: ", ")
        let calleeNames = callees.prefix(8).map { graph.nodes[$0].displayName }.joined(separator: ", ")

        // Keep the excerpt bounded: the on-device context window is small, and a
        // thousand-line function would crowd out the instructions.
        let excerpt = source.count > 3_000 ? String(source.prefix(3_000)) + "\n…" : source

        var context = ""
        if !callerNames.isEmpty { context += "\nCalled by: \(callerNames)" }
        if !calleeNames.isEmpty { context += "\nCalls: \(calleeNames)" }

        return """
        Language: \(node.language.displayName)
        Name: \(node.displayName)\(context)

        Source:
        ```
        \(excerpt)
        ```

        \(language == .uz ? "Bu kod nima qilishini tushuntiring." : "Explain what this code does.")
        """
    }
}
