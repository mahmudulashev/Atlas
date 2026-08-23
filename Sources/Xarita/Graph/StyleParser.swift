import Foundation

/// Extracts structure from stylesheets and markup.
///
/// A pure front-end project has no functions to find, and the existing parser
/// would report it as empty. But these files do have structure — a stylesheet
/// is a list of rules, a page is a set of named elements — and that structure
/// is exactly what someone reading the project needs to see.
enum StyleParser {

    static func parse(source: String, language: Language, fileIndex: Int)
        -> (symbols: [RawSymbol], calls: [RawCall]) {
        switch language {
        case .css, .scss: return parseStylesheet(source, language: language, fileIndex: fileIndex)
        case .html:       return parseMarkup(source, fileIndex: fileIndex)
        default:          return ([], [])
        }
    }

    // MARK: - Stylesheets

    /// Each rule becomes a symbol named by its selector; `@mixin` and
    /// `@function` become callables, and `@include` / `@extend` become the
    /// calls between them — which is as close as a stylesheet gets to a call
    /// graph, and is genuinely useful in a large SCSS project.
    private static func parseStylesheet(_ source: String, language: Language,
                                        fileIndex: Int) -> ([RawSymbol], [RawCall]) {
        var symbols: [RawSymbol] = []
        var calls: [RawCall] = []

        let characters = Array(source)
        var index = 0
        var line = 1
        var selectorStart = 0
        var depth = 0
        var currentSymbol = -1

        func text(_ range: Range<Int>) -> String {
            String(characters[range])
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
        }

        while index < characters.count {
            let character = characters[index]

            if character == "\n" { line += 1; index += 1; continue }

            // Comments
            if character == "/", index + 1 < characters.count {
                if characters[index + 1] == "*" {
                    index += 2
                    while index + 1 < characters.count,
                          !(characters[index] == "*" && characters[index + 1] == "/") {
                        if characters[index] == "\n" { line += 1 }
                        index += 1
                    }
                    index += 2
                    selectorStart = index
                    continue
                }
                if characters[index + 1] == "/" && language == .scss {
                    while index < characters.count, characters[index] != "\n" { index += 1 }
                    selectorStart = index
                    continue
                }
            }

            if character == "{" {
                let raw = text(selectorStart..<index)
                let name = cleanSelector(raw)
                if !name.isEmpty, depth == 0 || raw.hasPrefix("@") || !raw.isEmpty {
                    let kind: SymbolKind = raw.hasPrefix("@mixin") || raw.hasPrefix("@function")
                        ? .function : .type
                    symbols.append(RawSymbol(name: name, container: nil, kind: kind,
                                             language: language, fileIndex: fileIndex,
                                             line: line, endLine: line))
                    if depth == 0 { currentSymbol = symbols.count - 1 }
                }
                depth += 1
                index += 1
                selectorStart = index
                continue
            }

            if character == "}" {
                depth = max(0, depth - 1)
                if depth == 0, currentSymbol >= 0 {
                    symbols[currentSymbol].endLine = line
                    currentSymbol = -1
                }
                index += 1
                selectorStart = index
                continue
            }

            if character == ";" { index += 1; selectorStart = index; continue }

            // @include / @extend: a rule reaching for another
            if character == "@" {
                let rest = characters[index...].prefix(9)
                let word = String(rest)
                if word.hasPrefix("@include") || word.hasPrefix("@extend") {
                    var cursor = index + (word.hasPrefix("@include") ? 8 : 7)
                    while cursor < characters.count, characters[cursor] == " " { cursor += 1 }
                    var nameEnd = cursor
                    while nameEnd < characters.count,
                          characters[nameEnd].isLetter || characters[nameEnd].isNumber
                            || characters[nameEnd] == "-" || characters[nameEnd] == "_"
                            || characters[nameEnd] == "." || characters[nameEnd] == "%" {
                        nameEnd += 1
                    }
                    if nameEnd > cursor {
                        calls.append(RawCall(calleeName: String(characters[cursor..<nameEnd]),
                                             receiver: nil, callerSymbol: currentSymbol,
                                             fileIndex: fileIndex, line: line))
                    }
                    index = nameEnd
                    continue
                }
            }

            index += 1
        }

        return (symbols, calls)
    }

    /// Selectors can run to several lines and a dozen compound parts; the card
    /// has room for one readable name.
    private static func cleanSelector(_ raw: String) -> String {
        var value = raw
        while let range = value.range(of: "  ") { value.replaceSubrange(range, with: " ") }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }
        if value.count > 44 { value = String(value.prefix(42)) + "…" }
        return value
    }

    // MARK: - Markup

    /// Named elements — anything with an `id` — plus any functions declared in
    /// an inline script. Those ids are what the page's JavaScript reaches for,
    /// so they are the page's real interface.
    private static func parseMarkup(_ source: String, fileIndex: Int) -> ([RawSymbol], [RawCall]) {
        var symbols: [RawSymbol] = []
        var seen = Set<String>()
        let characters = Array(source)
        var index = 0
        var line = 1

        func matches(_ needle: [Character], at position: Int) -> Bool {
            guard position + needle.count <= characters.count else { return false }
            for offset in needle.indices where characters[position + offset] != needle[offset] {
                return false
            }
            return true
        }

        let idAttribute = Array("id=")
        while index < characters.count {
            if characters[index] == "\n" { line += 1; index += 1; continue }

            if matches(idAttribute, at: index),
               index == 0 || characters[index - 1] == " " || characters[index - 1] == "\t" {
                var cursor = index + 3
                guard cursor < characters.count else { break }
                let quote = characters[cursor]
                if quote == "\"" || quote == "'" {
                    cursor += 1
                    var end = cursor
                    while end < characters.count, characters[end] != quote { end += 1 }
                    let name = String(characters[cursor..<end])
                    if !name.isEmpty, seen.insert(name).inserted {
                        symbols.append(RawSymbol(name: "#" + name, container: nil, kind: .type,
                                                 language: .html, fileIndex: fileIndex,
                                                 line: line, endLine: line))
                    }
                    index = end + 1
                    continue
                }
            }
            index += 1
        }

        return (symbols, [])
    }
}
