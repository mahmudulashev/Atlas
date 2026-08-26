import Foundation

/// What a run of source text is, for colouring.
///
/// A role, not a colour: the two clients paint from the same palette but each
/// reaches for it in its own way, and the engine has no business knowing what
/// a keyword looks like.
enum SyntaxRole: String, Sendable {
    case plain, comment, string, number, keyword, function, type, punct
}

/// Divides a source snippet into coloured runs.
///
/// Runs the same lexer the analyser uses, with trivia enabled so comments and
/// string literals come through as tokens. Sharing the lexer means
/// highlighting can never disagree with parsing about where a string ends — a
/// classic source of highlighters that break on an apostrophe inside a
/// comment. A client that brought its own lexer would give that up, which is
/// why this is here and not in a view.
enum Highlighter {

    /// A run of bytes and what it is. Offsets are into the UTF-8 of the
    /// source, which is what the lexer works in.
    struct Span: Sendable {
        let offset: Int
        let length: Int
        let role: SyntaxRole
    }

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

    /// Every byte of `source` accounted for, in order.
    ///
    /// The gaps between tokens — whitespace, and punctuation the lexer did not
    /// capture — come back as `.plain` rather than being left out, so a client
    /// can rebuild the text exactly by walking the spans.
    static func spans(source: String, language: Language) -> [Span] {
        let tokens = Tokenizer(source: source, language: language, includeTrivia: true).tokenize()
        let total = source.utf8.count

        var spans: [Span] = []
        spans.reserveCapacity(tokens.count * 2)
        var cursor = 0

        func add(_ offset: Int, _ length: Int, _ role: SyntaxRole) {
            guard length > 0, offset >= 0, offset + length <= total else { return }
            spans.append(Span(offset: offset, length: length, role: role))
        }

        for (index, token) in tokens.enumerated() {
            if token.offset > cursor { add(cursor, token.offset - cursor, .plain) }

            let role: SyntaxRole
            switch token.kind {
            case .comment: role = .comment
            case .string:  role = .string
            case .number:  role = .number
            case .punct:   role = .punct
            case .identifier:
                if commonKeywords.contains(token.text) {
                    role = .keyword
                } else if isCallSite(tokens, index) {
                    role = .function
                } else if token.text.first?.isUppercase == true {
                    role = .type
                } else {
                    role = .plain
                }
            }
            add(token.offset, token.length, role)
            cursor = max(cursor, token.offset + token.length)
        }
        if cursor < total { add(cursor, total - cursor, .plain) }
        return spans
    }

    private static func isCallSite(_ tokens: [Token], _ index: Int) -> Bool {
        let next = index + 1
        guard next < tokens.count else { return false }
        return tokens[next].kind == .punct && tokens[next].punct == 0x28
    }
}
