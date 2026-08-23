import Foundation

/// A classification of what a function does, rendered into whichever language
/// the reader has chosen.
///
/// This exists because Apple's on-device model refuses to generate Uzbek — it
/// returns `unsupportedLanguageOrLocale` for both generation and translation,
/// and Apple Translate has no Uzbek pair either. Rather than leaving Uzbek
/// readers with English prose, the model is asked only to *choose* from fixed
/// options, in English, which it does reliably. Every word the reader sees is
/// then written by us, so the result is fully idiomatic Uzbek at no download
/// cost and no translation quality risk.
struct CodeSummary {

    enum Operation: String, CaseIterable {
        case search, transform, validate, read, write, create, delete
        case calculate, parse, format, display, connect, coordinate, configure

        var uz: String {
            switch self {
            case .search:     return "qidiruv"
            case .transform:  return "oʻzgartirish"
            case .validate:   return "tekshirish"
            case .read:       return "oʻqish"
            case .write:      return "yozish"
            case .create:     return "yaratish"
            case .delete:     return "oʻchirish"
            case .calculate:  return "hisoblash"
            case .parse:      return "tahlil qilish"
            case .format:     return "shaklga solish"
            case .display:    return "koʻrsatish"
            case .connect:    return "ulanish"
            case .coordinate: return "boshqarish"
            case .configure:  return "sozlash"
            }
        }

        var en: String {
            switch self {
            case .search:     return "searches"
            case .transform:  return "transforms data"
            case .validate:   return "checks something is valid"
            case .read:       return "reads data"
            case .write:      return "writes data"
            case .create:     return "creates something"
            case .delete:     return "removes something"
            case .calculate:  return "calculates a value"
            case .parse:      return "parses input"
            case .format:     return "formats data for output"
            case .display:    return "puts something on screen"
            case .connect:    return "talks to another system"
            case .coordinate: return "coordinates other functions"
            case .configure:  return "sets things up"
            }
        }
    }

    enum Target: String, CaseIterable {
        case memory, file, network, database, screen
        case userInput = "user input"
        case nothingExternal = "nothing external"

        var uz: String {
            switch self {
            case .memory:          return "xotiradagi maʼlumot ustida ishlaydi"
            case .file:            return "fayllar bilan ishlaydi"
            case .network:         return "tarmoqqa murojaat qiladi"
            case .database:        return "maʼlumotlar bazasi bilan ishlaydi"
            case .screen:          return "ekranga chiqaradi"
            case .userInput:       return "foydalanuvchi kiritgan maʼlumot bilan ishlaydi"
            case .nothingExternal: return "tashqi hech narsaga tegmaydi"
            }
        }

        var en: String {
            switch self {
            case .memory:          return "works on data already in memory"
            case .file:            return "touches files on disk"
            case .network:         return "goes over the network"
            case .database:        return "works against a database"
            case .screen:          return "draws to the screen"
            case .userInput:       return "handles input from the user"
            case .nothingExternal: return "touches nothing outside itself"
            }
        }
    }

    var operation: Operation
    var target: Target
    var canFail: Bool
    var repeats: Bool

    // MARK: - Rendering

    /// Composes the sentence. The model contributed four choices; every word
    /// here is ours, which is what makes a fully Uzbek result possible.
    func sentence(for node: GraphNode, language: AppLanguage, t: L10n) -> String {
        var parts: [String] = []

        if language == .uz {
            parts.append("`\(node.name)` — **\(operation.uz)** funksiyasi.")
            parts.append(target.uz.prefix(1).uppercased() + target.uz.dropFirst() + ".")
            if repeats { parts.append("Bir nechta element boʻylab takrorlanadi.") }
            parts.append(canFail ? "Xato berishi mumkin — chaqirganda buni hisobga olish kerak."
                                 : "Xato bermaydi.")
            parts.append("\(node.span) qator, \(node.branches) ta shart — "
                         + t.difficultyName(node.difficulty).lowercased() + ".")
        } else {
            parts.append("`\(node.name)` **\(operation.en)**.")
            parts.append("It " + target.en + ".")
            if repeats { parts.append("It loops over several items.") }
            parts.append(canFail ? "It can fail, so callers need to handle that."
                                 : "It cannot fail.")
            parts.append("\(node.span) lines, \(node.branches) branches — "
                         + t.difficultyName(node.difficulty).lowercased() + ".")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Decoding

    static func from(operation: String, target: String,
                     canFail: String, repeats: String) -> CodeSummary? {
        guard let op = Operation(rawValue: operation.lowercased()) else { return nil }
        let tgt = Target(rawValue: target.lowercased()) ?? .memory
        return CodeSummary(operation: op,
                           target: tgt,
                           canFail: canFail.lowercased().hasPrefix("y"),
                           repeats: repeats.lowercased().hasPrefix("y"))
    }
}
