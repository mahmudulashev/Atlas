import SwiftUI

/// Colours a source snippet.
///
/// Runs the same lexer the analyser uses, with trivia enabled so comments and
/// string literals come through as tokens. Sharing the lexer means highlighting
/// can never disagree with parsing about where a string ends — a classic source
/// of highlighters that break on an apostrophe inside a comment.
enum SyntaxHighlighter {

    private static let commonKeywords: Set<String> = [
        "func", "return", "if", "else", "for", "while", "in", "let", "var", "class",
        "struct", "enum", "protocol", "extension", "import", "public", "private",
        "internal", "static", "final", "guard", "switch", "case", "default", "break",
        "continue", "do", "try", "catch", "throw", "throws", "async", "await", "self",
        "init", "deinit", "nil", "true", "false", "def", "elif", "pass", "lambda",
        "None", "True", "False", "and", "or", "not", "is", "from", "as", "with",
        "yield", "global", "function", "const", "new", "delete", "typeof", "instanceof",
        "export", "this", "null", "undefined", "interface", "type", "implements",
        "package", "void", "int", "long", "short", "char", "float", "double", "bool",
        "boolean", "unsigned", "signed", "sizeof", "typedef", "namespace", "using",
        "template", "virtual", "override", "abstract", "synchronized", "throws",
        "fn", "mut", "impl", "trait", "pub", "match", "where", "unsafe", "crate",
        "go", "chan", "defer", "range", "map", "select", "fun", "val", "when",
        "object", "companion", "suspend", "echo", "elseif", "endif", "require"
    ]

    static func highlight(_ source: String, language: Language) -> AttributedString {
        let tokens = Tokenizer(source: source, language: language, includeTrivia: true).tokenize()
        let bytes = Array(source.utf8)

        var result = AttributedString()
        var cursor = 0

        func append(_ range: Range<Int>, color: Color?, italic: Bool = false) {
            guard range.lowerBound < range.upperBound,
                  range.upperBound <= bytes.count else { return }
            var piece = AttributedString(String(decoding: bytes[range], as: UTF8.self))
            if let color { piece.foregroundColor = color }
            if italic { piece.inlinePresentationIntent = .emphasized }
            result.append(piece)
        }

        for (index, token) in tokens.enumerated() {
            // Everything between tokens — whitespace and punctuation we didn't
            // capture — is emitted untouched so the text stays byte-exact.
            if token.offset > cursor {
                append(cursor..<token.offset, color: Theme.codePlain)
            }
            let range = token.offset..<(token.offset + token.length)

            switch token.kind {
            case .comment:
                append(range, color: Theme.codeComment, italic: true)
            case .string:
                append(range, color: Theme.codeString)
            case .number:
                append(range, color: Theme.codeNumber)
            case .identifier:
                if commonKeywords.contains(token.text) {
                    append(range, color: Theme.codeKeyword)
                } else if isCallSite(tokens, index) {
                    append(range, color: Theme.codeFunction)
                } else if token.text.first?.isUppercase == true {
                    append(range, color: Theme.codeType)
                } else {
                    append(range, color: Theme.codePlain)
                }
            case .punct:
                append(range, color: Theme.codePunct)
            }
            cursor = max(cursor, token.offset + token.length)
        }
        if cursor < bytes.count {
            append(cursor..<bytes.count, color: Theme.codePlain)
        }
        return result
    }

    private static func isCallSite(_ tokens: [Token], _ index: Int) -> Bool {
        let next = index + 1
        guard next < tokens.count else { return false }
        return tokens[next].kind == .punct && tokens[next].punct == 0x28
    }
}
