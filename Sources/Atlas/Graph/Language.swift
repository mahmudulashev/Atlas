import Foundation

/// A source language Atlas can read.
///
/// Each case carries the lexical rules the tokenizer needs (comment markers,
/// string delimiters) plus the declaration shapes the parser looks for. Adding
/// a language means adding a case here — nothing else in the pipeline changes.
enum Language: String, CaseIterable, Codable, Sendable {
    case swift, python, javascript, typescript, c, cpp, go, java, rust, ruby, csharp, php, kotlin
    case html, css, scss, vue, svelte

    // MARK: - Detection

    static func detect(path: String) -> Language? {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":                       return .swift
        case "py", "pyw":                   return .python
        case "js", "jsx", "mjs", "cjs":     return .javascript
        case "ts", "tsx", "mts":            return .typescript
        case "c", "h":                      return .c
        case "cc", "cpp", "cxx", "hpp", "hh", "hxx": return .cpp
        case "go":                          return .go
        case "java":                        return .java
        case "rs":                          return .rust
        case "rb":                          return .ruby
        case "cs":                          return .csharp
        case "php":                         return .php
        case "kt", "kts":                   return .kotlin
        case "html", "htm", "xhtml":        return .html
        case "css":                         return .css
        case "scss", "sass", "less":        return .scss
        case "vue":                         return .vue
        case "svelte":                      return .svelte
        default:                            return nil
        }
    }

    var displayName: String {
        switch self {
        case .swift:      return "Swift"
        case .python:     return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .c:          return "C"
        case .cpp:        return "C++"
        case .go:         return "Go"
        case .java:       return "Java"
        case .rust:       return "Rust"
        case .ruby:       return "Ruby"
        case .csharp:     return "C#"
        case .php:        return "PHP"
        case .kotlin:     return "Kotlin"
        case .html:       return "HTML"
        case .css:        return "CSS"
        case .scss:       return "SCSS"
        case .vue:        return "Vue"
        case .svelte:     return "Svelte"
        }
    }

    // MARK: - Lexical rules

    var lineComment: [String] {
        switch self {
        case .python, .ruby: return ["#"]
        case .php:           return ["//", "#"]
        case .css, .html:    return []          // neither has a line comment
        default:             return ["//"]
        }
    }

    var blockComment: (open: String, close: String)? {
        switch self {
        case .python, .ruby: return nil
        case .html:          return ("<!--", "-->")
        default:             return ("/*", "*/")
        }
    }

    /// Languages where a nested `/* */` closes only after balanced pairs.
    var nestsBlockComments: Bool {
        switch self {
        case .swift, .rust, .kotlin: return true
        default:                     return false
        }
    }

    /// Triple-quoted / heredoc-ish string forms, checked before single delimiters.
    var multiStringDelimiters: [String] {
        switch self {
        case .python: return ["\"\"\"", "'''"]
        case .swift:  return ["\"\"\""]
        default:      return []
        }
    }

    var stringDelimiters: [Character] {
        switch self {
        case .python, .javascript, .typescript, .ruby, .php,
             .vue, .svelte, .html, .css, .scss:               return ["\"", "'", "`"]
        case .go, .rust:                                     return ["\"", "`"]
        case .c, .cpp, .java, .csharp, .kotlin:              return ["\"", "'"]
        default:                                             return ["\""]
        }
    }

    /// True when blocks are delimited by indentation rather than braces.
    var isIndentScoped: Bool { self == .python }

    /// Stylesheets and markup have no functions to find; their structure is
    /// rules and elements, which `StyleParser` extracts instead.
    var isMarkupOrStyle: Bool {
        self == .html || self == .css || self == .scss
    }

    /// Files a beginner's front-end project is actually made of.
    var isWeb: Bool {
        switch self {
        case .html, .css, .scss, .vue, .svelte, .javascript, .typescript: return true
        default: return false
        }
    }

    // MARK: - Declarations

    /// Keywords that introduce a callable, and how many identifiers to skip
    /// before the name. `func foo` → skip 0; Go's `func (r T) foo` is handled
    /// separately by the parser.
    var functionKeywords: Set<String> {
        switch self {
        case .swift:                  return ["func", "init", "subscript", "deinit"]
        case .python:                 return ["def"]
        case .javascript, .typescript: return ["function"]
        case .go:                     return ["func"]
        case .rust:                   return ["fn"]
        case .ruby:                   return ["def"]
        case .php:                    return ["function"]
        case .kotlin:                 return ["fun"]
        case .c, .cpp, .java, .csharp: return []   // shape-detected, no keyword
        case .vue, .svelte:           return ["function"]
        case .html, .css, .scss:      return []   // handled by StyleParser
        }
    }

    /// Keywords that introduce a named container (used for scope names).
    var typeKeywords: Set<String> {
        switch self {
        case .swift:  return ["class", "struct", "enum", "protocol", "extension", "actor"]
        case .python, .ruby: return ["class"]
        case .javascript, .typescript: return ["class", "interface"]
        case .go:     return ["type"]
        case .rust:   return ["struct", "enum", "trait", "impl", "mod"]
        case .java, .csharp, .kotlin: return ["class", "interface", "enum", "struct", "record", "object"]
        case .cpp:    return ["class", "struct", "namespace", "union"]
        case .c:      return ["struct", "union", "enum"]
        case .php:    return ["class", "interface", "trait"]
        case .vue, .svelte: return ["class", "interface"]
        case .html, .css, .scss: return []
        }
    }

    /// Words that look like calls but are control flow — never treated as callees.
    var controlKeywords: Set<String> {
        let shared: Set<String> = ["if", "else", "for", "while", "switch", "case", "return",
                                   "catch", "do", "try", "guard", "defer", "throw", "with",
                                   "elif", "except", "finally", "match", "when", "unless",
                                   "and", "or", "not", "in", "is", "as", "new", "delete",
                                   "sizeof", "typeof", "await", "yield", "assert", "print",
                                   "lambda", "select", "go", "chan", "range", "using", "where"]
        switch self {
        case .c, .cpp: return shared.union(["static_cast", "dynamic_cast", "const_cast",
                                            "reinterpret_cast", "operator", "template"])
        default:       return shared
        }
    }

    /// Type-ish words that show up before a C-style function name.
    static let cTypeNoise: Set<String> = [
        "static", "inline", "extern", "const", "unsigned", "signed", "struct", "enum",
        "union", "public", "private", "protected", "final", "abstract", "synchronized",
        "override", "virtual", "explicit", "constexpr", "noexcept", "friend", "typedef",
        "void", "int", "char", "long", "short", "float", "double", "bool", "auto", "size_t"
    ]
}
