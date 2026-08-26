import SwiftUI

/// Paints a source snippet.
///
/// The dividing up is `Highlighter`'s, in the engine, which runs the same
/// lexer the analyser does. All that is left here is choosing the ink for
/// each kind of run — which is the one part of this that is a design decision
/// rather than a lexical one.
enum SyntaxHighlighter {

    static func highlight(_ source: String, language: Language) -> AttributedString {
        let bytes = Array(source.utf8)
        var result = AttributedString()

        for span in Highlighter.spans(source: source, language: language) {
            let end = span.offset + span.length
            guard end <= bytes.count else { continue }
            var piece = AttributedString(String(decoding: bytes[span.offset..<end], as: UTF8.self))
            piece.foregroundColor = colour(for: span.role)
            if span.role == .comment { piece.inlinePresentationIntent = .emphasized }
            result.append(piece)
        }
        return result
    }

    private static func colour(for role: SyntaxRole) -> Color {
        switch role {
        case .comment:  return Theme.codeComment
        case .string:   return Theme.codeString
        case .number:   return Theme.codeNumber
        case .keyword:  return Theme.codeKeyword
        case .function: return Theme.codeFunction
        case .type:     return Theme.codeType
        case .punct:    return Theme.codePunct
        case .plain:    return Theme.codePlain
        }
    }
}
