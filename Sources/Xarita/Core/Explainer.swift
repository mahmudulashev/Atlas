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

    /// True when the answer on screen had to be produced in English because the
    /// on-device model refused the requested language. Apple's model supports
    /// neither Uzbek generation nor Uzbek translation, so rather than showing
    /// nothing we fall back and say so.
    @Published private(set) var fellBackToEnglish = false
    @Published private(set) var lastError: String?

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
        fellBackToEnglish = false
        lastError = nil

        guard modelState.canGenerate else { return }

        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else { return }

        isGenerating = true

        task = Task { [weak self] in
            guard let self else { return }
            defer { self.isGenerating = false }

            // Two different routes, because the model's abilities differ by
            // language. English gets free prose, which reads better. Uzbek gets
            // guided classification rendered through our own wording, because
            // the model will not produce Uzbek at all.
            if language == .uz {
                if let summary = await Self.classify(node: node, source: source) {
                    guard !Task.isCancelled else { return }
                    let text = summary.sentence(for: node, language: .uz,
                                                t: L10n(language: .uz))
                    self.streaming = text
                    self.cache[node.id] = text
                    return
                }
                self.lastError = "classificationFailed"
                return
            }

            do {
                let session = LanguageModelSession(
                    model: .default, instructions: Self.instructions(for: .en))
                let prompt = Self.buildPrompt(node: node, graph: graph,
                                              source: source, language: .en)
                let stream = session.streamResponse(
                    to: prompt, options: GenerationOptions(temperature: 0.3))
                var text = ""
                for try await partial in stream {
                    guard !Task.isCancelled else { return }
                    text = partial.content
                    self.streaming = text
                }
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.cache[node.id] = text
                }
            } catch {
                // The model occasionally rejects perfectly ordinary source with
                // "unsupported language" — short symbolic string literals seem
                // to defeat its language detector. Falling back to the guided
                // route keeps something useful on screen.
                self.lastError = Self.describe(error)
                if let summary = await Self.classify(node: node, source: source) {
                    let text = summary.sentence(for: node, language: .en,
                                                t: L10n(language: .en))
                    self.streaming = text
                    self.cache[node.id] = text
                }
            }
        }
        #endif
    }

    #if canImport(FoundationModels)
    /// Asks the model to pick from fixed options rather than to write prose.
    ///
    /// Retried once: the classifier is cheap (well under a second) and its
    /// occasional refusals are not deterministic.
    @available(macOS 26.0, *)
    private static func classify(node: GraphNode, source: String) async -> CodeSummary? {
        let excerpt = source.count > 2_000 ? String(source.prefix(2_000)) : source

        guard let schema = try? buildSchema() else { return nil }

        for attempt in 0..<2 {
            do {
                let session = LanguageModelSession(model: .default, instructions: """
                You classify source code. Choose the single best option for each field.
                """)
                let response = try await session.respond(
                    to: "Classify this \(node.language.displayName) function named \(node.name):\n\n\(excerpt)",
                    schema: schema,
                    options: GenerationOptions(temperature: 0.1))

                let content = response.content
                func field(_ key: String) -> String {
                    (try? content.value(String.self, forProperty: key)) ?? ""
                }
                if let summary = CodeSummary.from(operation: field("operation"),
                                                  target: field("target"),
                                                  canFail: field("canFail"),
                                                  repeats: field("repeats")) {
                    return summary
                }
            } catch {
                if attempt == 1 { return nil }
                continue
            }
        }
        return nil
    }

    @available(macOS 26.0, *)
    private static func describe(_ error: Error) -> String {
        let text = "\(error)"
        if text.contains("unsupportedLanguageOrLocale") { return "unsupportedLanguage" }
        if text.contains("guardrailViolation")          { return "guardrail" }
        if text.contains("exceededContextWindowSize")   { return "tooLong" }
        return "generic"
    }

    @available(macOS 26.0, *)
    private static func buildSchema() throws -> GenerationSchema {
        func choice(_ name: String, _ options: [String], _ description: String)
            -> DynamicGenerationSchema.Property {
            .init(name: name, description: description,
                  schema: DynamicGenerationSchema(name: name.capitalized, anyOf: options))
        }

        let root = DynamicGenerationSchema(
            name: "CodeSummary",
            description: "A classification of what a function does",
            properties: [
                choice("operation", CodeSummary.Operation.allCases.map(\.rawValue),
                       "The single best verb for what this function primarily does"),
                choice("target", CodeSummary.Target.allCases.map(\.rawValue),
                       "What the function primarily acts on"),
                choice("canFail", ["yes", "no"],
                       "Whether it can throw an error or return a failure"),
                choice("repeats", ["yes", "no"],
                       "Whether it loops or recurses over multiple items"),
            ])
        return try GenerationSchema(root: root, dependencies: [])
    }
    #endif

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
