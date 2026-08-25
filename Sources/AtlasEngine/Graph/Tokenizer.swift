import Foundation

/// A single meaningful token. Comments and string bodies never reach the parser —
/// the tokenizer consumes them so that a `(` inside a string or a `func` inside a
/// comment can't fabricate a symbol.
struct Token {
    enum Kind: UInt8 { case identifier, punct, number, comment, string }

    let kind: Kind
    let text: String      // identifiers only
    let punct: UInt8      // punctuation byte only
    let line: Int         // 1-based
    let offset: Int       // byte offset of the token start
    let length: Int       // byte length, for source highlighting
    let indent: Int       // indentation column of the line this token sits on
    let firstOnLine: Bool
}

/// Byte-level lexer.
///
/// Works directly on UTF-8 bytes rather than `Character`s: code is overwhelmingly
/// ASCII, and scanning bytes avoids grapheme-breaking overhead on files that can
/// run to hundreds of thousands of lines. Bytes >= 0x80 are folded into
/// identifiers so non-ASCII names still tokenize as single units.
struct Tokenizer {

    let language: Language
    private let bytes: [UInt8]

    /// When true, comments and string literals are emitted as tokens instead of
    /// being consumed. The parser wants them gone; the syntax highlighter needs
    /// them, and both walk the same lexer rather than keeping two in step.
    private let includeTrivia: Bool

    init(source: String, language: Language, includeTrivia: Bool = false) {
        self.language = language
        self.bytes = Array(source.utf8)
        self.includeTrivia = includeTrivia
    }

    // MARK: - Byte classes

    @inline(__always)
    private static func isIdentStart(_ b: UInt8) -> Bool {
        (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || b == 0x5F || b >= 0x80
    }

    @inline(__always)
    private static func isIdentBody(_ b: UInt8) -> Bool {
        isIdentStart(b) || (b >= 0x30 && b <= 0x39)
    }

    @inline(__always)
    private static func isDigit(_ b: UInt8) -> Bool { b >= 0x30 && b <= 0x39 }

    @inline(__always)
    private static func isSpace(_ b: UInt8) -> Bool { b == 0x20 || b == 0x09 || b == 0x0D }

    // MARK: - Lexing

    func tokenize() -> [Token] {
        var tokens: [Token] = []
        tokens.reserveCapacity(bytes.count / 6)

        let n = bytes.count
        var i = 0
        var line = 1
        var lineStart = 0
        var indent = 0
        var seenTokenOnLine = false
        var indentMeasured = false

        let lineCommentMarkers = language.lineComment.map { Array($0.utf8) }
        let blockOpen = language.blockComment.map { Array($0.open.utf8) }
        let blockClose = language.blockComment.map { Array($0.close.utf8) }
        let multiStrings = language.multiStringDelimiters.map { Array($0.utf8) }
        let stringBytes = Set(language.stringDelimiters.compactMap { $0.asciiValue })

        @inline(__always)
        func matches(_ pattern: [UInt8], at idx: Int) -> Bool {
            guard idx + pattern.count <= n else { return false }
            for k in 0..<pattern.count where bytes[idx + k] != pattern[k] { return false }
            return true
        }

        @inline(__always)
        func newline(at idx: Int) {
            line += 1
            lineStart = idx + 1
            indent = 0
            seenTokenOnLine = false
            indentMeasured = false
        }

        while i < n {
            let b = bytes[i]

            // Newlines
            if b == 0x0A {
                newline(at: i)
                i += 1
                continue
            }

            // Leading whitespace defines the line's indent (Python needs this).
            if Self.isSpace(b) {
                if !indentMeasured && !seenTokenOnLine {
                    indent += (b == 0x09) ? 4 : 1
                }
                i += 1
                continue
            }
            indentMeasured = true

            // Line comments
            var consumed = false
            for marker in lineCommentMarkers where matches(marker, at: i) {
                let start = i
                while i < n && bytes[i] != 0x0A { i += 1 }
                if includeTrivia {
                    tokens.append(Token(kind: .comment, text: "", punct: 0, line: line,
                                        offset: start, length: i - start,
                                        indent: indent, firstOnLine: !seenTokenOnLine))
                }
                seenTokenOnLine = true
                consumed = true
                break
            }
            if consumed { continue }

            // Block comments
            if let open = blockOpen, let close = blockClose, matches(open, at: i) {
                let start = i
                let startLine = line
                var depth = 1
                i += open.count
                while i < n && depth > 0 {
                    if bytes[i] == 0x0A { newline(at: i); i += 1; continue }
                    if language.nestsBlockComments && matches(open, at: i) {
                        depth += 1; i += open.count; continue
                    }
                    if matches(close, at: i) {
                        depth -= 1; i += close.count; continue
                    }
                    i += 1
                }
                if includeTrivia {
                    tokens.append(Token(kind: .comment, text: "", punct: 0, line: startLine,
                                        offset: start, length: i - start,
                                        indent: indent, firstOnLine: !seenTokenOnLine))
                }
                seenTokenOnLine = true
                continue
            }

            // Multi-line strings (""" / ''')
            var handledMultiline = false
            for delim in multiStrings where matches(delim, at: i) {
                let start = i
                let startLine = line
                i += delim.count
                while i < n && !matches(delim, at: i) {
                    if bytes[i] == 0x0A { newline(at: i) }
                    if bytes[i] == 0x5C { i += 1 }   // escape
                    i += 1
                }
                i = min(i + delim.count, n)
                if includeTrivia {
                    tokens.append(Token(kind: .string, text: "", punct: 0, line: startLine,
                                        offset: start, length: i - start,
                                        indent: indent, firstOnLine: !seenTokenOnLine))
                }
                seenTokenOnLine = true
                handledMultiline = true
                break
            }
            if handledMultiline { continue }

            // Single-delimiter strings
            if stringBytes.contains(b) {
                let quote = b
                let start = i
                let startLine = line
                i += 1
                while i < n {
                    let c = bytes[i]
                    if c == 0x5C { i += 2; continue }          // escape
                    if c == 0x0A {                             // unterminated
                        if quote != 0x60 { break }             // backticks may span lines
                        newline(at: i)
                    }
                    if c == quote { i += 1; break }
                    i += 1
                }
                if includeTrivia {
                    tokens.append(Token(kind: .string, text: "", punct: 0, line: startLine,
                                        offset: start, length: i - start,
                                        indent: indent, firstOnLine: !seenTokenOnLine))
                }
                seenTokenOnLine = true
                continue
            }

            // Identifiers
            if Self.isIdentStart(b) {
                let start = i
                while i < n && Self.isIdentBody(bytes[i]) { i += 1 }
                let text = String(decoding: bytes[start..<i], as: UTF8.self)
                tokens.append(Token(kind: .identifier, text: text, punct: 0,
                                    line: line, offset: start, length: i - start,
                                    indent: indent, firstOnLine: !seenTokenOnLine))
                seenTokenOnLine = true
                continue
            }

            // Numbers (skipped, but must not be mistaken for identifiers)
            if Self.isDigit(b) {
                let start = i
                while i < n, Self.isIdentBody(bytes[i]) || bytes[i] == 0x2E { i += 1 }
                tokens.append(Token(kind: .number, text: "", punct: 0,
                                    line: line, offset: start, length: i - start,
                                    indent: indent, firstOnLine: !seenTokenOnLine))
                seenTokenOnLine = true
                continue
            }

            // Punctuation
            tokens.append(Token(kind: .punct, text: "", punct: b,
                                line: line, offset: i, length: 1,
                                indent: indent, firstOnLine: !seenTokenOnLine))
            seenTokenOnLine = true
            i += 1
        }

        _ = lineStart
        return tokens
    }
}
