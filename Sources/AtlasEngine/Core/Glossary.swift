import Foundation

/// Programming vocabulary, explained.
///
/// A beginner reading real code hits two problems at once: the logic, and the
/// words. English-language documentation solves neither for someone learning in
/// Uzbek. This glossary covers the terms that actually appear in source — the
/// ones you meet before anyone has taught them to you.
struct Glossary {

    struct Term {
        let key: String            // token as it appears in code
        let titleUz: String
        let titleEn: String
        let bodyUz: String
        let bodyEn: String
    }

    /// Looked up by exact token match, so entries are keyed by the spelling that
    /// appears in source rather than by prose name.
    static let terms: [Term] = [
        Term(key: "func", titleUz: "func — funksiya", titleEn: "func — function",
             bodyUz: "Nomlangan kod boʻlagi. Bir marta yoziladi, keyin nomi bilan istalgancha chaqiriladi. Retsept kabi: bir marta yozib qoʻyasan, har safar qaytadan oʻylab oʻtirmaysan.",
             bodyEn: "A named block of code. Written once, then called by name as often as needed."),
        Term(key: "return", titleUz: "return — qaytarish",
             titleEn: "return — return a value",
             bodyUz: "Funksiyani shu yerda toʻxtatadi va natijani chaqirgan joyga qaytaradi. `return` dan keyingi qatorlar bajarilmaydi.",
             bodyEn: "Stops the function here and hands a value back to whoever called it. Lines after it don't run."),
        Term(key: "if", titleUz: "if — shart", titleEn: "if — condition",
             bodyUz: "Shart toʻgʻri boʻlsa, ichidagi kod bajariladi. Boʻlmasa, oʻtkazib yuboriladi.",
             bodyEn: "Runs the code inside only when the condition holds."),
        Term(key: "else", titleUz: "else — aks holda", titleEn: "else — otherwise",
             bodyUz: "Yuqoridagi `if` sharti bajarilmasa, shu yerdagi kod ishlaydi.",
             bodyEn: "Runs when the `if` above it did not."),
        Term(key: "for", titleUz: "for — takrorlash", titleEn: "for — loop",
             bodyUz: "Roʻyxatdagi har bir element uchun bir marta ishlaydi. 100 ta element boʻlsa, 100 marta aylanadi.",
             bodyEn: "Runs once for each item in a collection."),
        Term(key: "while", titleUz: "while — shart boʻlgunicha",
             titleEn: "while — loop while true",
             bodyUz: "Shart toʻgʻri boʻlib turgan ekan, takrorlanaveradi. Shart hech qachon buzilmasa, dastur qotib qoladi.",
             bodyEn: "Repeats as long as the condition stays true. If it never becomes false, the program hangs."),
        Term(key: "class", titleUz: "class — sinf", titleEn: "class — class",
             bodyUz: "Maʼlumot va u bilan ishlaydigan funksiyalarni bitta nom ostida birlashtiradi. Undan nusxalar (obyektlar) yaratiladi.",
             bodyEn: "Bundles data together with the functions that work on it. Objects are made from it."),
        Term(key: "struct", titleUz: "struct — tuzilma", titleEn: "struct — structure",
             bodyUz: "`class` ga oʻxshaydi, lekin nusxa koʻchirilganda alohida nusxa boʻladi — havola emas. Kichik maʼlumotlar uchun qulay.",
             bodyEn: "Like a class, but copied by value rather than shared by reference."),
        Term(key: "enum", titleUz: "enum — sanoq turi", titleEn: "enum — enumeration",
             bodyUz: "Cheklangan variantlar roʻyxati. Masalan: qizil, sariq, yashil — boshqasi boʻlishi mumkin emas.",
             bodyEn: "A fixed set of possible values — red, yellow, green, and nothing else."),
        Term(key: "protocol", titleUz: "protocol — shartnoma", titleEn: "protocol — interface",
             bodyUz: "Qanday funksiyalar boʻlishi kerakligini belgilaydi, lekin ularni yozmaydi. Kim qabul qilsa, oʻsha yozadi.",
             bodyEn: "Declares what functions must exist without writing them. Whoever adopts it supplies them."),
        Term(key: "interface", titleUz: "interface — shartnoma", titleEn: "interface",
             bodyUz: "Qanday funksiyalar boʻlishi kerakligini belgilaydi, lekin ularni yozmaydi.",
             bodyEn: "Declares what functions must exist without implementing them."),
        Term(key: "async", titleUz: "async — asinxron", titleEn: "async — asynchronous",
             bodyUz: "Bu funksiya kutishi mumkin — masalan, internetdan javob kelishini. Kutayotganda dastur qotib qolmaydi, boshqa ishlarni qiladi.",
             bodyEn: "This function may wait — for a network reply, say — without freezing the rest of the program."),
        Term(key: "await", titleUz: "await — kutish", titleEn: "await — wait for a result",
             bodyUz: "Natija tayyor boʻlgunicha shu yerda kutadi, lekin butun dasturni toʻxtatmaydi.",
             bodyEn: "Waits here for a result, without blocking the whole program."),
        Term(key: "try", titleUz: "try — urinib koʻrish", titleEn: "try — attempt",
             bodyUz: "Bu amal xato berishi mumkin. Xato chiqsa, `catch` uni ushlaydi.",
             bodyEn: "This operation may fail; a `catch` handles it if it does."),
        Term(key: "catch", titleUz: "catch — xatoni ushlash", titleEn: "catch — handle an error",
             bodyUz: "Yuqorida xato chiqqan boʻlsa, dastur qulab tushmasligi uchun shu yerda ushlanadi.",
             bodyEn: "Catches an error from above so the program doesn't crash."),
        Term(key: "throw", titleUz: "throw — xato chiqarish", titleEn: "throw — raise an error",
             bodyUz: "\"Bu ishni bajara olmadim\" degani. Chaqirgan tomon buni hal qilishi kerak.",
             bodyEn: "Signals failure and hands the problem to the caller."),
        Term(key: "guard", titleUz: "guard — qoʻriqchi", titleEn: "guard — early exit",
             bodyUz: "Shart bajarilmasa, funksiyadan darrov chiqib ketadi. Kodning qolgani chuqur ichkariga kirmasligi uchun ishlatiladi.",
             bodyEn: "Leaves the function immediately unless a condition holds, keeping the rest of the code unnested."),
        Term(key: "nil", titleUz: "nil — hech narsa", titleEn: "nil — no value",
             bodyUz: "Qiymat yoʻqligini bildiradi. Nol emas, boʻsh satr emas — umuman hech narsa.",
             bodyEn: "The absence of a value. Not zero, not an empty string — nothing at all."),
        Term(key: "null", titleUz: "null — hech narsa", titleEn: "null — no value",
             bodyUz: "Qiymat yoʻqligini bildiradi.",
             bodyEn: "The absence of a value."),
        Term(key: "None", titleUz: "None — hech narsa", titleEn: "None — no value",
             bodyUz: "Python'da qiymat yoʻqligini bildiradi.",
             bodyEn: "Python's way of saying there is no value."),
        Term(key: "static", titleUz: "static — umumiy", titleEn: "static — shared",
             bodyUz: "Har bir nusxaga emas, butun sinfga tegishli. Nusxa yaratmasdan ishlatiladi.",
             bodyEn: "Belongs to the type itself rather than to any one instance."),
        Term(key: "private", titleUz: "private — yopiq", titleEn: "private",
             bodyUz: "Faqat shu fayl yoki sinf ichida ishlatiladi. Tashqaridan koʻrinmaydi.",
             bodyEn: "Visible only inside this file or type."),
        Term(key: "public", titleUz: "public — ochiq", titleEn: "public",
             bodyUz: "Loyihaning istalgan joyidan ishlatsa boʻladi.",
             bodyEn: "Usable from anywhere in the project."),
        Term(key: "override", titleUz: "override — qayta yozish", titleEn: "override",
             bodyUz: "Ota-sinfdagi funksiyani oʻzgacha qilib qaytadan yozadi.",
             bodyEn: "Replaces a function inherited from a parent type with a different version."),
        Term(key: "extension", titleUz: "extension — kengaytma", titleEn: "extension",
             bodyUz: "Mavjud tipga yangi funksiya qoʻshadi, uning asl kodiga tegmasdan.",
             bodyEn: "Adds functions to an existing type without touching its original source."),
        Term(key: "lambda", titleUz: "lambda — nomsiz funksiya", titleEn: "lambda",
             bodyUz: "Nomi yoʻq, joyida yoziladigan kichkina funksiya.",
             bodyEn: "A small function written inline, with no name."),
        Term(key: "yield", titleUz: "yield — birma-bir qaytarish", titleEn: "yield",
             bodyUz: "Hammasini birdan emas, bittalab qaytaradi. Katta maʼlumotni xotiraga sigʻdirmasdan oʻqishga yordam beradi.",
             bodyEn: "Produces values one at a time instead of building the whole result in memory."),
        Term(key: "defer", titleUz: "defer — oxirida bajarish", titleEn: "defer",
             bodyUz: "Funksiya tugaganda — qanday tugashidan qatʼi nazar — bajariladigan kod. Faylni yopish kabi ishlar uchun.",
             bodyEn: "Runs when the function exits, however it exits. Used for cleanup."),
        Term(key: "import", titleUz: "import — chaqirib olish", titleEn: "import",
             bodyUz: "Boshqa fayl yoki kutubxonadagi kodni shu yerda ishlatish uchun olib keladi.",
             bodyEn: "Brings code from another file or library into this one."),
        Term(key: "var", titleUz: "var — oʻzgaruvchi", titleEn: "var — variable",
             bodyUz: "Qiymati keyin oʻzgarishi mumkin boʻlgan nom.",
             bodyEn: "A name whose value can change later."),
        Term(key: "let", titleUz: "let — oʻzgarmas", titleEn: "let — constant",
             bodyUz: "Bir marta qiymat beriladi, keyin oʻzgartirib boʻlmaydi.",
             bodyEn: "Assigned once and never changed."),
        Term(key: "const", titleUz: "const — oʻzgarmas", titleEn: "const — constant",
             bodyUz: "Bir marta qiymat beriladi, keyin oʻzgartirib boʻlmaydi.",
             bodyEn: "Assigned once and never changed."),
        Term(key: "switch", titleUz: "switch — tanlov", titleEn: "switch",
             bodyUz: "Bir qiymatni koʻp variant bilan solishtiradi. Uzun `if-else` zanjirining tozaroq koʻrinishi.",
             bodyEn: "Compares one value against many cases — a cleaner long if-else chain."),
        Term(key: "break", titleUz: "break — chiqish", titleEn: "break",
             bodyUz: "Takrorlanishni shu yerda toʻxtatadi va tsikldan chiqadi.",
             bodyEn: "Stops the loop immediately."),
        Term(key: "continue", titleUz: "continue — keyingisiga oʻtish", titleEn: "continue",
             bodyUz: "Shu aylanishni tashlab, keyingisiga oʻtadi.",
             bodyEn: "Skips the rest of this iteration and starts the next."),
        Term(key: "self", titleUz: "self — oʻzi", titleEn: "self",
             bodyUz: "Shu obyektning oʻziga ishora. \"Mening oʻzimning\" degani.",
             bodyEn: "Refers to the object the code is running inside."),
        Term(key: "this", titleUz: "this — oʻzi", titleEn: "this",
             bodyUz: "Shu obyektning oʻziga ishora.",
             bodyEn: "Refers to the object the code is running inside."),
        Term(key: "new", titleUz: "new — yangi nusxa", titleEn: "new",
             bodyUz: "Sinfdan yangi obyekt yaratadi.",
             bodyEn: "Creates a new object from a class."),
        Term(key: "init", titleUz: "init — yaratuvchi", titleEn: "init — initializer",
             bodyUz: "Obyekt yaratilganda birinchi ishlaydigan funksiya. Boshlangʻich qiymatlarni oʻrnatadi.",
             bodyEn: "Runs when an object is created, setting up its starting values."),
        Term(key: "throws", titleUz: "throws — xato berishi mumkin", titleEn: "throws",
             bodyUz: "Bu funksiya xato chiqarishi mumkinligini oldindan aytadi.",
             bodyEn: "Declares that this function may fail."),
        Term(key: "mut", titleUz: "mut — oʻzgartirsa boʻladi", titleEn: "mut — mutable",
             bodyUz: "Rust'da: bu qiymatni oʻzgartirish mumkin. Belgilanmasa — oʻzgarmas.",
             bodyEn: "Rust: this value may be changed. Without it, values are immutable."),
        Term(key: "impl", titleUz: "impl — amalga oshirish", titleEn: "impl",
             bodyUz: "Rust'da: tipga funksiyalar qoʻshadigan blok.",
             bodyEn: "Rust: a block that attaches functions to a type."),
        Term(key: "go", titleUz: "go — parallel ishga tushirish", titleEn: "go — goroutine",
             bodyUz: "Go'da: funksiyani yonma-yon, alohida ishga tushiradi.",
             bodyEn: "Go: runs a function concurrently alongside the current one."),
        Term(key: "chan", titleUz: "chan — kanal", titleEn: "chan — channel",
             bodyUz: "Go'da: parallel ishlayotgan qismlar bir-biriga maʼlumot uzatadigan quvur.",
             bodyEn: "Go: a pipe concurrent parts use to pass values to each other."),
    ]

    private static let index: [String: Term] = {
        var map: [String: Term] = [:]
        for term in terms { map[term.key] = term }
        return map
    }()

    /// Terms appearing in a snippet, in the order a reader meets them.
    static func found(in source: String, language: Language, limit: Int = 6) -> [Term] {
        let tokens = Tokenizer(source: source, language: language).tokenize()
        var seen = Set<String>()
        var result: [Term] = []
        for token in tokens where token.kind == .identifier {
            guard !seen.contains(token.text), let term = index[token.text] else { continue }
            seen.insert(token.text)
            result.append(term)
            if result.count >= limit { break }
        }
        return result
    }

    static func title(_ term: Term, language: AppLanguage) -> String {
        language == .uz ? term.titleUz : term.titleEn
    }

    static func body(_ term: Term, language: AppLanguage) -> String {
        language == .uz ? term.bodyUz : term.bodyEn
    }
}
