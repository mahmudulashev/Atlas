import Foundation

/// A structured reading of what a function does, rendered into the reader's
/// language from fixed vocabulary.
///
/// Apple's on-device model refuses to generate Uzbek — `unsupportedLanguageOrLocale`
/// for both generation and translation — and Apple Translate has no Uzbek pair.
/// Machine translation was considered and rejected: NLLB-200 does support Uzbek,
/// but it is trained on general prose and renders the vocabulary that matters
/// here word-for-word and wrongly ("thread" becomes the kind of thread you sew
/// with). So the model is asked only to *choose* among fixed options, in
/// English, which it does reliably — and every word the reader sees is written
/// here. The result is idiomatic Uzbek at no download cost, with the technical
/// terms under our control.
struct CodeSummary {

    // MARK: - Vocabulary

    enum Operation: String, CaseIterable {
        case search, transform, validate, read, write, create, delete
        case calculate, parse, format, display, connect, coordinate, configure

        var uz: String {
            switch self {
            case .search:     return "biror narsani qidiradi"
            case .transform:  return "maʼlumotni bir koʻrinishdan boshqasiga oʻtkazadi"
            case .validate:   return "maʼlumot toʻgʻriligini tekshiradi"
            case .read:       return "maʼlumot oʻqiydi"
            case .write:      return "maʼlumot yozadi"
            case .create:     return "yangi narsa yaratadi"
            case .delete:     return "biror narsani oʻchiradi"
            case .calculate:  return "hisob-kitob qiladi"
            case .parse:      return "matnni boʻlaklarga ajratib, maʼnosini aniqlaydi"
            case .format:     return "maʼlumotni koʻrsatishga tayyorlaydi"
            case .display:    return "ekranga chiqaradi"
            case .connect:    return "boshqa tizim bilan bogʻlanadi"
            case .coordinate: return "boshqa funksiyalarni boshqaradi"
            case .configure:  return "sozlamalarni oʻrnatadi"
            }
        }

        var en: String {
            switch self {
            case .search:     return "searches for something"
            case .transform:  return "converts data from one shape to another"
            case .validate:   return "checks that data is valid"
            case .read:       return "reads data"
            case .write:      return "writes data"
            case .create:     return "creates something new"
            case .delete:     return "removes something"
            case .calculate:  return "works out a value"
            case .parse:      return "breaks text apart and works out what it means"
            case .format:     return "prepares data for display"
            case .display:    return "puts something on screen"
            case .connect:    return "talks to another system"
            case .coordinate: return "directs other functions"
            case .configure:  return "sets things up"
            }
        }

        /// The idea a beginner has to hold to follow this kind of code, and the
        /// mistake they usually make about it. Written by hand per operation —
        /// this is the part a translator would ruin.
        var pitfallUz: String {
            switch self {
            case .search:
                return "Koʻp boshlovchilar qidiruv «topilmadi» holatini unutadi. Natija boʻsh boʻlishi mumkinligini doim hisobga ol."
            case .transform:
                return "Bu funksiya asl maʼlumotni oʻzgartirmaydi — yangisini qaytaradi. Natijani oʻzlashtirib olishni unutma."
            case .validate:
                return "Tekshirish faqat «ha» yoki «yoʻq» deydi. Nima uchun notoʻgʻri ekanini bilmoqchi boʻlsang, boshqa joyga qarash kerak."
            case .read:
                return "Oʻqish har doim muvaffaqiyatli boʻlmaydi — fayl yoʻq boʻlishi yoki ruxsat berilmasligi mumkin."
            case .write:
                return "Yozish maʼlumotni ustiga yozib yuborishi mumkin. Eski qiymat kerak boʻlsa, avval oʻqib olish kerak."
            case .create:
                return "Yaratilgan narsa keyin kim tomonidan tozalanishini bilib ol — aks holda xotira toʻlib ketadi."
            case .delete:
                return "Oʻchirishni orqaga qaytarib boʻlmaydi. Bu funksiyani chaqirishdan oldin toʻgʻri narsani oʻchirayotganingga ishonch hosil qil."
            case .calculate:
                return "Chetki holatlarni tekshir: nol, manfiy son, juda katta qiymat. Xatolar odatda shu yerda yashiringan."
            case .parse:
                return "Bu funksiya matnni tushunmaydi — faqat boʻlaklarga ajratadi. Maʼnoni anglash keyingi bosqichda boʻladi."
            case .format:
                return "Koʻrinishni oʻzgartiradi, maʼnoni emas. Bu yerda mantiq qidirma."
            case .display:
                return "Ekranga chizadi, lekin maʼlumotni oʻzgartirmaydi. Nimadir notoʻgʻri koʻrinsa, xato koʻpincha bu yerda emas."
            case .connect:
                return "Tarmoq har doim ishlaydi deb oʻylama. Sekin javob va uzilish — odatiy hol, ularni hisobga olish kerak."
            case .coordinate:
                return "Bu funksiya oʻzi kam ish qiladi — asosiy ish u chaqirgan funksiyalarda. Ularga ham qarab chiq."
            case .configure:
                return "Sozlama bir marta, dastur boshida oʻrnatiladi. Keyin oʻzgartirsang, taʼsir qilmasligi mumkin."
            }
        }

        var pitfallEn: String {
            switch self {
            case .search:     return "Beginners forget the not-found case. The result can be empty; always handle that."
            case .transform:  return "It returns a new value rather than changing the original. Don't discard the result."
            case .validate:   return "It only answers yes or no. To learn *why* something is invalid, look elsewhere."
            case .read:       return "Reading can fail — the file may be missing or unreadable."
            case .write:      return "Writing can overwrite. Read the old value first if you still need it."
            case .create:     return "Find out who cleans up what this creates, or it will pile up."
            case .delete:     return "Deleting cannot be undone. Be sure of the target before calling this."
            case .calculate:  return "Check the edges: zero, negative, very large. That is where the bugs live."
            case .parse:      return "It does not understand the text, it only splits it. Meaning comes later."
            case .format:     return "It changes appearance, not meaning. Don't look for logic here."
            case .display:    return "It draws but does not change data. If something looks wrong, the cause is usually elsewhere."
            case .connect:    return "Never assume the network works. Slowness and failure are normal and must be handled."
            case .coordinate: return "It does little itself — the real work is in what it calls. Follow those too."
            case .configure:  return "Configuration is set once at startup. Changing it later may have no effect."
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
            case .file:            return "diskdagi fayllar bilan ishlaydi"
            case .network:         return "tarmoq orqali murojaat qiladi"
            case .database:        return "maʼlumotlar bazasiga tegadi"
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
            case .database:        return "reaches a database"
            case .screen:          return "draws to the screen"
            case .userInput:       return "handles input from the user"
            case .nothingExternal: return "touches nothing outside itself"
            }
        }
    }

    enum DataShape: String, CaseIterable {
        case nothing, text, number, list, object, boolean, file, unknown

        var uz: String {
            switch self {
            case .nothing: return "hech narsa"
            case .text:    return "matn"
            case .number:  return "son"
            case .list:    return "roʻyxat"
            case .object:  return "obyekt"
            case .boolean: return "ha/yoʻq javobi"
            case .file:    return "fayl"
            case .unknown: return "aralash maʼlumot"
            }
        }

        var en: String {
            switch self {
            case .nothing: return "nothing"
            case .text:    return "text"
            case .number:  return "a number"
            case .list:    return "a list"
            case .object:  return "an object"
            case .boolean: return "a yes/no answer"
            case .file:    return "a file"
            case .unknown: return "mixed data"
            }
        }
    }

    enum Timing: String, CaseIterable {
        case startup, everyRequest, userAction, onDemand, cleanup

        var uz: String {
            switch self {
            case .startup:      return "Dastur ishga tushganda chaqiriladi"
            case .everyRequest: return "Har bir soʻrov yoki hodisada qayta chaqiriladi"
            case .userAction:   return "Foydalanuvchi biror amal qilganda ishlaydi"
            case .onDemand:     return "Kerak boʻlganda, boshqa kod chaqirganda ishlaydi"
            case .cleanup:      return "Ish tugaganda, tozalash uchun chaqiriladi"
            }
        }

        var en: String {
            switch self {
            case .startup:      return "Runs when the program starts"
            case .everyRequest: return "Runs again for every request or event"
            case .userAction:   return "Runs when the user does something"
            case .onDemand:     return "Runs when other code needs it"
            case .cleanup:      return "Runs at the end, to clean up"
            }
        }
    }

    // MARK: - Fields

    var operation: Operation
    var target: Target
    var input: DataShape
    var output: DataShape
    var timing: Timing
    var canFail: Bool
    var changesState: Bool
    var repeats: Bool

    // MARK: - Rendering

    /// Composes the paragraph. The model contributed eight choices; every word
    /// below is ours, which is what makes a genuinely Uzbek result possible.
    func paragraph(for node: GraphNode, language: AppLanguage, t: L10n) -> String {
        var lines: [String] = []

        if language == .uz {
            lines.append("`\(node.name)` — \(operation.uz).")
            lines.append("Kirish: **\(input.uz)**. Chiqish: **\(output.uz)**.")
            lines.append(timing.uz + ".")
            lines.append(changesState
                ? "Maʼlumotni oʻzgartiradi — chaqirgandan keyin holat oʻzgargan boʻladi."
                : "Hech narsani oʻzgartirmaydi, faqat oʻqiydi. Xohlagancha chaqirsang ham xavfsiz.")
            if repeats { lines.append("Bir nechta element boʻylab takrorlanadi.") }
            lines.append(canFail
                ? "Xato berishi mumkin — chaqirganda buni hisobga olish kerak."
                : "Xato bermaydi.")
            lines.append("\(target.uz.prefix(1).uppercased())\(target.uz.dropFirst()).")
            lines.append("\(node.span) qator, \(node.branches) ta shart — "
                         + t.difficultyName(node.difficulty).lowercased() + ".")
            lines.append("\n**Koʻp adashiladigan joyi.** " + operation.pitfallUz)
        } else {
            lines.append("`\(node.name)` \(operation.en).")
            lines.append("Takes **\(input.en)**, gives back **\(output.en)**.")
            lines.append(timing.en + ".")
            lines.append(changesState
                ? "It changes state, so things are different after you call it."
                : "It changes nothing and only reads. Safe to call as often as you like.")
            if repeats { lines.append("It loops over several items.") }
            lines.append(canFail
                ? "It can fail, so callers need to handle that."
                : "It cannot fail.")
            lines.append("It \(target.en).")
            lines.append("\(node.span) lines, \(node.branches) branches — "
                         + t.difficultyName(node.difficulty).lowercased() + ".")
            lines.append("\n**Where people trip up.** " + operation.pitfallEn)
        }

        return lines.joined(separator: " ")
    }

    // MARK: - Decoding

    static func from(_ field: (String) -> String) -> CodeSummary? {
        guard let op = Operation(rawValue: field("operation").lowercased()) else { return nil }
        return CodeSummary(
            operation: op,
            target: Target(rawValue: field("target").lowercased()) ?? .memory,
            input: DataShape(rawValue: field("input").lowercased()) ?? .unknown,
            output: DataShape(rawValue: field("output").lowercased()) ?? .unknown,
            timing: Timing(rawValue: field("timing")) ?? .onDemand,
            canFail: field("canFail").lowercased().hasPrefix("y"),
            changesState: field("changesState").lowercased().hasPrefix("y"),
            repeats: field("repeats").lowercased().hasPrefix("y"))
    }
}
