import Foundation
import SwiftUI

/// UI language. Independent of the system locale: a developer working in an
/// English toolchain may still want the interface in Uzbek, so the choice is
/// explicit and persisted.
enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case uz, en

    var displayName: String {
        switch self {
        case .uz: return "O‘zbekcha"
        case .en: return "English"
        }
    }

    var flagless: String {
        switch self {
        case .uz: return "UZ"
        case .en: return "EN"
        }
    }

    /// Best guess on first launch, from the user's preferred languages.
    static var systemDefault: AppLanguage {
        for code in Locale.preferredLanguages {
            if code.hasPrefix("uz") { return .uz }
            if code.hasPrefix("en") { return .en }
        }
        return .en
    }
}

/// Every string in the interface, in both languages.
///
/// A plain struct rather than `.strings` files: the app ships as a hand-built
/// bundle without an asset pipeline, and keeping both languages side by side in
/// one file makes a missing translation a compile error rather than a silent
/// fallback to the key name.
struct L10n {

    let language: AppLanguage

    private func s(_ uz: String, _ en: String) -> String {
        language == .uz ? uz : en
    }

    // MARK: - App level

    var appTagline: String        { s("Kodning shaklini koʻr", "See the shape of a codebase") }

    // MARK: - Welcome

    var welcomeTitle: String      { s("Loyihani tanlang", "Open a project") }
    var welcomeBody: String       { s("Papkani bu yerga tashlang yoki tanlang. Xarita kodni oʻqib, funksiyalar oʻrtasidagi bogʻlanishlar xaritasini chizadi.",
                                      "Drop a folder here, or choose one. Xarita reads the code and draws the map of how its functions connect.") }
    var chooseFolder: String      { s("Papka tanlash", "Choose folder…") }
    var dropHere: String          { s("Papkani tashlang", "Drop folder here") }
    var recentProjects: String    { s("Yaqinda ochilganlar", "Recent projects") }
    var supportedLanguages: String { s("Qoʻllab-quvvatlanadigan tillar", "Supported languages") }

    // MARK: - Analysis

    var analyzing: String         { s("Tahlil qilinmoqda", "Analyzing") }
    var stageScanning: String     { s("Fayllar qidirilmoqda", "Scanning files") }
    var stageParsing: String      { s("Kod oʻqilmoqda", "Parsing code") }
    var stageResolving: String    { s("Bogʻlanishlar aniqlanmoqda", "Resolving references") }
    var stageLaying: String       { s("Xarita joylashtirilmoqda", "Laying out map") }
    var analysisFailed: String    { s("Tahlil qilib boʻlmadi", "Analysis failed") }
    var noSourceFiles: String     { s("Bu papkada tanish kod fayllari topilmadi",
                                      "No recognised source files in this folder") }

    // MARK: - Stats

    var files: String             { s("Fayl", "Files") }
    var lines: String             { s("Qator", "Lines") }
    var symbols: String           { s("Funksiya", "Symbols") }
    var connections: String       { s("Bogʻlanish", "Connections") }
    var parseTime: String         { s("Oʻqish vaqti", "Parse time") }
    var languagesLabel: String    { s("Tillar", "Languages") }

    // MARK: - Panels

    var overview: String          { s("Umumiy", "Overview") }
    var hubs: String              { s("Markazlar", "Hubs") }
    var hubsHint: String          { s("Eng koʻp chaqiriladigan funksiyalar — kod shu yerga toʻplanadi",
                                      "The most-called functions — where the code converges") }
    var entryPoints: String       { s("Kirish nuqtalari", "Entry points") }
    var unreachable: String       { s("Ishlatilmagan", "Unreachable") }
    var unreachableHint: String   { s("Hech kim chaqirmaydi. Bu shubha, isbot emas — framework orqali chaqirilgan boʻlishi mumkin.",
                                      "Nothing calls these. A hint, not proof — they may be invoked by a framework.") }
    var search: String            { s("Qidirish", "Search") }
    var searchPlaceholder: String { s("Funksiya nomi…", "Function name…") }
    var noResults: String         { s("Hech narsa topilmadi", "No results") }

    // MARK: - Inspector

    var callers: String           { s("Chaqiruvchilar", "Callers") }
    var callees: String           { s("Chaqiradi", "Calls") }
    var definedIn: String         { s("Eʼlon qilingan", "Defined in") }
    var kind: String              { s("Turi", "Kind") }
    var noCallers: String         { s("Chaqiruvchi yoʻq", "No callers") }
    var noCallees: String         { s("Hech nimani chaqirmaydi", "Calls nothing") }
    var openInEditor: String      { s("Muharrirda ochish", "Open in editor") }
    var copyPath: String          { s("Yoʻlni nusxalash", "Copy path") }
    var focusNode: String         { s("Shunga fokuslash", "Focus on this") }

    func kindName(_ k: SymbolKind) -> String {
        switch k {
        case .function:     return s("funksiya", "function")
        case .method:       return s("metod", "method")
        case .initializer:  return s("konstruktor", "initializer")
        case .type:         return s("tip", "type")
        case .closureOrVar: return s("yopilma", "closure")
        }
    }

    // MARK: - Explanation panel

    var whatThisDoes: String      { s("Bu nima qiladi", "What this does") }
    var explainThis: String       { s("Tushuntirib ber", "Explain this") }
    var thinking: String          { s("Oʻylayapti…", "Thinking…") }
    var theFacts: String          { s("Aniq maʼlumot", "The facts") }
    var pickSomething: String     { s("Chapdan bir funksiyani tanlang",
                                      "Pick a function on the left") }
    /// The two languages take different routes through the model, so the note
    /// that explains what just happened differs too.
    var onDeviceNote: String {
        s("Model kodni tasnifladi, gapni Xarita yozdi — hech narsa internetga chiqmaydi",
          "Apple's on-device model — nothing leaves your Mac")
    }

    var englishFallbackNote: String {
        s("Apple modeli oʻzbekcha yoza olmaydi, shuning uchun u faqat kodni tasniflaydi — gapni Xarita oʻzi yozadi.",
          "Apple's model classifies the code; the sentence itself is written by Xarita.")
    }

    var aiOffTitle: String        { s("AI tushuntirish yoqilmagan", "AI explanations are off") }
    var aiOffNeedsEnable: String  { s("Apple Intelligence yoqilmagan. Yoqsangiz, har bir funksiyani sodda tilda tushuntirib beradi. Ilovaning qolgan qismi busiz ham toʻliq ishlaydi.",
                                      "Apple Intelligence isn't enabled. Turn it on and each function gets a plain-language explanation. Everything else in the app works without it.") }
    var aiOffDownloading: String  { s("Model yuklanmoqda. Tugagach bu yerda paydo boʻladi.",
                                      "The model is still downloading. It will appear here when it's ready.") }
    var aiOffIneligible: String   { s("Bu Mac Apple Intelligence'ni qoʻllab-quvvatlamaydi. Apple Silicon (M1 va undan yangi) kerak.",
                                      "This Mac can't run Apple Intelligence — it needs Apple Silicon (M1 or newer).") }
    var aiOffOldOS: String        { s("Qurilma ichidagi model macOS 26 va undan yangisini talab qiladi.",
                                      "The on-device model requires macOS 26 or newer.") }
    var openSettings: String      { s("Sozlamalarni ochish", "Open Settings") }

    var codeMenu: String          { s("Kod", "Code") }

    // MARK: - Orientation

    var projectIs: String         { s("Bu —", "This is a") }
    var beginReading: String      { s("Oʻqishni boshlash", "Start reading") }
    var suggestedRoute: String    { s("Taklif qilingan yoʻnalish", "Suggested route") }
    var routeHint: String {
        s("Dastur ishini boshlagan joydan boshlanadi va chaqiruvlar boʻylab boradi. Har bir bosqichga oldingisidan yetib kelinadi.",
          "It starts where the program starts and follows the calls. Each step is reached by the one before it.")
    }
    var routeEmpty: String {
        s("Bu loyihada aniq boshlanish nuqtasi topilmadi. Chapdagi roʻyxatdan oʻzing tanlashing mumkin.",
          "No clear starting point was found here. Pick something from the list instead.")
    }
    var youAreHere: String        { s("shu yerdasiz", "you are here") }
    var stepWord: String          { s("bosqich", "step") }
    var nextStepLabel: String     { s("Keyingi", "Next") }
    var prevStepLabel: String     { s("Oldingi", "Previous") }
    var backToOverview: String    { s("Umumiy koʻrinish", "Overview") }
    var routeLabel: String        { s("Yoʻnalish", "Route") }
    var everythingElse: String    { s("Qolgan hammasi", "Everything else") }

    // MARK: - Questions

    var askQuestion: String       { s("Savol berish", "Ask a question") }
    var questionWhoCalls: String  { s("Bu qayerdan chaqiriladi?", "Where is this called from?") }
    var questionWhyExists: String { s("Nega bu funksiya kerak?", "Why does this exist?") }
    var questionWhatBreaks: String { s("Bu yerda nima xato ketishi mumkin?", "What can go wrong here?") }
    var questionSimpler: String   { s("Yanada soddaroq tushuntir", "Explain it more simply") }

    // MARK: - Architecture

    var architecture: String      { s("Tuzilma", "Architecture") }
    var overviewTab: String       { s("Umumiy", "Overview") }
    var readingTab: String        { s("Oʻqish", "Reading") }
    var cycles: String            { s("aylanma", "cycles") }
    var showTests: String         { s("Testlarni koʻrsatish", "Show tests") }
    var architectureHint: String {
        s("Har bir kartochka — bitta fayl. Chiziqlar kim kimni chaqirishini koʻrsatadi. Chapdan oʻngga — chaqiruvchidan chaqirilganga.",
          "Each card is one file. The lines show what calls what, running left to right from caller to callee.")
    }

    // MARK: - Issues

    var issuesTab: String         { s("Xatolar", "Findings") }
    var issuesTitle: String       { s("Eʼtibor talab qiladigan joylar", "Worth a second look") }
    var issuesHint: String {
        s("Bularning hammasi kod tahlilidan olingan — har biri aniq fayl va qatorni koʻrsatadi. Bu xato degani emas, bu «shu yerga qarab qoʻy» degani.",
          "All of this comes from the analysis, and every item points at a real file and line. These are not errors — they are places worth looking at.")
    }
    var issuesNone: String        { s("Eʼtibor talab qiladigan joy topilmadi.", "Nothing stood out.") }

    func severityName(_ s2: Issue.Severity) -> String {
        switch s2 {
        case .high:   return s("Muhim", "Important")
        case .medium: return s("Oʻrtacha", "Worth checking")
        case .low:    return s("Kichik", "Minor")
        }
    }

    var previewBadge: String      { s("koʻrinish", "preview") }
    var widgetNeedsSigning: String {
        s("Widget toʻliq yozilgan va ilova ichiga joylashtirilgan. Lekin macOS uchinchi tomon kengaytmalarini faqat Apple Developer ID bilan imzolangan boʻlsa roʻyxatga oladi — shusiz u Bildirishnoma markazida koʻrinmaydi. Yuqoridagi — oʻsha widget kodining haqiqiy natijasi.",
          "The widget is written and embedded in the app. macOS only registers third-party extensions signed with an Apple Developer ID, so it cannot appear in Notification Centre on an unsigned build. What you see above is the real widget code rendering.")
    }

    // MARK: - Tabs

    var tabAtlas: String          { s("Atlas", "Atlas") }
    var tabMap: String            { s("Xarita", "Map") }
    var tabRead: String           { s("Oʻqish", "Read") }
    var tabReview: String         { s("Koʻrib chiqish", "Review") }

    var tabAtlasHint: String      { s("shakli", "the shape") }
    var tabMapHint: String        { s("grafi", "the graph") }
    func tabReadHint(_ n: Int) -> String  { s("\(n) bosqich", "\(n) steps") }
    func tabReviewHint(_ n: Int) -> String { s("\(n) topilma", "\(n) findings") }

    // MARK: - Atlas

    var shapeOfIt: String         { s("Uning shakli", "The shape of it") }
    var callEdges: String         { s("chaqiruv", "call edges") }
    var districts: String         { s("Mahallalar", "Districts") }
    var districtInterface: String { s("INTERFEYS", "INTERFACE") }
    var districtLogic: String     { s("MANTIQ", "LOGIC") }
    var districtData: String      { s("MAʼLUMOT", "DATA") }
    var everyFigure: String {
        s("Quyidagi har bir raqam tahlilchi allaqachon qurgan grafdan olingan.",
          "Every figure below comes from the graph the analyser already builds.")
    }
    var startHereBlurb: String {
        s("Bu loyihaning eng koʻp qismiga yetib boradigan funksiyalar. Shu tartibda oʻqisang, loyihaning umurtqasi qoʻlingda boʻladi.",
          "The functions that reach the most of this codebase. Read them in order and you have the spine of the project.")
    }
    func reaches(_ n: Int) -> String { s("\(n) taga yetadi", "reaches \(n)") }
    var readArrow: String         { s("Oʻqish →", "Read →") }

    var viewLadder: String        { s("Zina", "Ladder") }
    var viewMatrix: String        { s("Jadval", "Matrix") }

    var matrixKeyForward: String  { s("oldinga bogʻliqlik", "forward dependency") }
    var matrixKeyBackward: String { s("orqaga — aylanma boʻlishi mumkin", "backward — may be a cycle") }
    var matrixKeyRow: String      { s("qator: nimani chaqiradi", "row: what it calls") }
    var matrixKeyColumn: String   { s("ustun: kim chaqiradi", "column: what calls it") }
    var backward: String          { s("orqaga", "backward") }

    // MARK: - Drift

    var driftTitle: String        { s("Oʻzgarishlar", "Drift") }
    func driftSince(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: language == .uz ? "uz" : "en_US")
        f.dateFormat = "d MMM"
        return language == .uz ? "oxirgi skandan beri · \(f.string(from: date))"
                               : "since last scan · \(f.string(from: date))"
    }
    var driftNone: String {
        s("Oxirgi skandan beri sezilarli oʻzgarish yoʻq.",
          "Nothing moved since the last scan.")
    }
    var driftFirst: String {
        s("Bu birinchi skan. Keyingi safar nima oʻzgargani shu yerda koʻrinadi.",
          "This is the first scan. Next time, what moved will appear here.")
    }

    func driftNote(_ e: Drift.Entry) -> String {
        switch (e.kind, language) {
        case (.newCycle, .uz):  return "Yangi aylanma bogʻliqlik. Oldin toʻgʻri chiziq edi."
        case (.newCycle, .en):  return "New cycle. It was a straight line before."
        case (.grew, .uz):      return "\(abs(e.delta)) qatorga oʻsdi." + (e.detail.isEmpty ? "" : " Shartlar ham koʻpaydi.")
        case (.grew, .en):      return "Grew \(abs(e.delta)) lines." + (e.detail.isEmpty ? "" : " And gained branches.")
        case (.shrank, .uz):    return "\(abs(e.delta)) qatorga qisqardi."
        case (.shrank, .en):    return "Shrank by \(abs(e.delta)) lines."
        case (.gainedCallers, .uz): return "\(abs(e.delta)) ta koʻproq joy shunga tayanadi endi."
        case (.gainedCallers, .en): return "\(abs(e.delta)) more places lean on it now."
        case (.lostCallers, .uz):   return "\(abs(e.delta)) ta kamroq chaqiruvchi. Undan koʻchish ketyapti."
        case (.lostCallers, .en):   return "\(abs(e.delta)) fewer callers. The migration off it is moving."
        case (.appeared, .uz):  return "\(abs(e.delta)) ta yangi funksiya qoʻshildi."
        case (.appeared, .en):  return "\(abs(e.delta)) new functions."
        case (.vanished, .uz):  return "\(abs(e.delta)) ta funksiya olib tashlandi."
        case (.vanished, .en):  return "\(abs(e.delta)) functions removed."
        }
    }

    // MARK: - Call chain and blast

    var callChain: String         { s("Chaqiruv zanjiri", "Call chain") }
    var callChainHint: String {
        s("Bu yerga qanday yetib kelinadi — kirish nuqtasidan boshlab.",
          "How execution reaches here, starting from an entry point.")
    }
    var blastTitle: String        { s("Taʼsir doirasi", "Blast radius") }
    func blastBody(symbols: Int, files: Int, hops: Int) -> String {
        language == .uz
            ? "\(hops) qadam narigacha \(symbols) ta funksiya, \(files) ta faylda."
            : "\(symbols) symbols across \(files) files, within \(hops) hops."
    }
    var hops: String              { s("qadam", "hops") }

    // MARK: - Difficulty

    var howHard: String           { s("Qanchalik qiyin", "How hard is this") }
    var difficultyEasy: String    { s("Oson", "Easy") }
    var difficultyModerate: String { s("Oʻrtacha", "Moderate") }
    var difficultyHard: String    { s("Qiyin", "Hard") }

    func difficultyName(_ d: GraphNode.Difficulty) -> String {
        switch d {
        case .easy:     return difficultyEasy
        case .moderate: return difficultyModerate
        case .hard:     return difficultyHard
        }
    }

    func difficultyReason(_ node: GraphNode) -> String {
        var bits: [String] = []
        if node.branches > 0 {
            bits.append(language == .uz ? "\(node.branches) ta shart/tsikl"
                                        : "\(node.branches) branch\(node.branches == 1 ? "" : "es")")
        }
        if node.maxNesting > 2 {
            bits.append(language == .uz ? "\(node.maxNesting) qavat ichma-ich"
                                        : "nested \(node.maxNesting) deep")
        }
        bits.append(language == .uz ? "\(node.span) qator" : "\(node.span) lines")
        return bits.joined(separator: " · ")
    }

    // MARK: - Glossary

    var glossary: String          { s("Bu koddagi soʻzlar", "Words in this code") }
    var glossaryHint: String      { s("Kodda uchragan atamalar — sodda tilda",
                                      "Terms that appear here, in plain language") }

    // MARK: - Reading progress

    var understood: String        { s("Tushundim", "I understand this") }
    var understoodMark: String    { s("Tushunilgan", "Understood") }
    var readingProgress: String   { s("Oʻqilgan", "Read so far") }
    func progressText(_ done: Int, _ total: Int) -> String {
        language == .uz ? "\(done) / \(total) funksiya" : "\(done) of \(total) functions"
    }
    var goBack: String            { s("Orqaga", "Back") }
    var goForward: String         { s("Oldinga", "Forward") }

    // MARK: - Junior guidance

    var startHere: String         { s("Shu yerdan boshlang", "Start here") }
    var startHereHint: String     { s("Bu funksiyalar loyihaning koʻp qismini harakatga keltiradi — notanish kodni oʻqishni shulardan boshlash qulay.",
                                      "These drive most of the project — the easiest place to start reading unfamiliar code.") }
    var browse: String            { s("Koʻrib chiqish", "Browse") }

    // MARK: - Canvas controls

    var fitToScreen: String       { s("Ekranga moslash", "Fit to screen")}
    var resetLayout: String       { s("Qaytadan joylashtirish", "Re-run layout") }
    var showLabels: String        { s("Nomlarni koʻrsatish", "Show labels") }
    var showExternal: String      { s("Tashqi chaqiruvlar", "External calls") }
    var zoomIn: String            { s("Kattalashtirish", "Zoom in") }
    var zoomOut: String           { s("Kichraytirish", "Zoom out") }

    // MARK: - Menu / settings

    var settings: String          { s("Sozlamalar", "Settings") }
    var interfaceLanguage: String { s("Interfeys tili", "Interface language") }
    var openProject: String       { s("Loyiha ochish…", "Open Project…") }
    var reanalyze: String         { s("Qayta tahlil qilish", "Re-analyze") }
    var close: String             { s("Yopish", "Close") }
    var notifications: String     { s("Bildirishnomalar", "Notifications") }
    var notifyOnFinish: String    { s("Tahlil tugaganda xabar berish", "Notify when analysis finishes") }

    // MARK: - Notifications

    var notifDoneTitle: String    { s("Tahlil tugadi", "Analysis complete") }
    func notifDoneBody(project: String, symbols: Int, seconds: Double) -> String {
        let t = String(format: "%.2f", seconds)
        return s("\(project): \(symbols) ta funksiya, \(t) soniyada",
                 "\(project): \(symbols) symbols in \(t)s")
    }

    // MARK: - Widget

    var widgetName: String        { s("Kod xaritasi", "Code map") }
    var widgetDescription: String { s("Oxirgi tahlil qilingan loyiha holati",
                                      "Status of your most recently analysed project") }
    var widgetEmpty: String       { s("Hali loyiha ochilmagan", "No project analysed yet") }
    var widgetTopHub: String      { s("Eng koʻp chaqiriladigan", "Most called") }

    // MARK: - Units

    func count(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 10_000    { return String(format: "%.0fk", Double(n) / 1_000) }
        if n >= 1_000     { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }

    func seconds(_ v: Double) -> String {
        v < 1 ? String(format: "%.0f ms", v * 1000) : String(format: "%.2f s", v)
    }
}

/// Observable holder so a language switch re-renders the whole interface.
@MainActor
final class Localization: ObservableObject {
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "uz.xarita.language") }
    }

    var t: L10n { L10n(language: language) }

    init() {
        if let raw = UserDefaults.standard.string(forKey: "uz.xarita.language"),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = .systemDefault
        }
    }
}
