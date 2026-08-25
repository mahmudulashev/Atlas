import Foundation

enum SymbolKind: String, Codable, Sendable {
    case function, method, initializer, type, closureOrVar

    var isCallable: Bool {
        self == .function || self == .method || self == .initializer || self == .closureOrVar
    }
}

/// A declaration found in one file, before cross-file resolution.
struct RawSymbol {
    var name: String
    var container: String?
    var kind: SymbolKind
    var language: Language
    var fileIndex: Int
    var line: Int
    var endLine: Int

    /// Decision points inside the body — `if`, loops, `case`, `catch`, `&&`,
    /// `||`. One plus this count is the classic cyclomatic complexity: the
    /// number of independent paths through the function.
    var branches: Int = 0

    /// Deepest nesting reached inside the body. Depth hurts readability more
    /// than length does, which is what a beginner needs warning about.
    var maxNesting: Int = 0
}

/// A call site found inside a declaration, before resolution.
struct RawCall {
    var calleeName: String
    var receiver: String?      // `foo` in `foo.bar()`
    var callerSymbol: Int      // index into the file's symbol array, -1 for file scope
    var fileIndex: Int
    var line: Int
}

/// Turns a token stream into declarations plus the calls inside them.
///
/// This is deliberately a *shape* parser, not a type checker: it recognises the
/// syntactic form of a declaration and the `name(` form of a call, then leaves
/// name resolution to `CodeGraph`. That is the same trade Sourcetrail made for
/// its lighter indexers — it costs some precision on overloads, and buys the
/// ability to read a codebase that doesn't compile, in any of a dozen languages.
struct Parser {

    let language: Language
    let fileIndex: Int

    private struct Scope {
        var name: String
        var kind: SymbolKind
        var symbolIndex: Int      // -1 when the scope isn't itself a symbol
        var braceDepth: Int       // depth this scope's body sits at
        var indent: Int           // for indentation-scoped languages
    }

    /// Words that introduce an independent path through a function.
    private static let decisionWords: Set<String> = [
        "if", "elif", "else", "for", "while", "case", "catch", "except",
        "guard", "when", "match", "unless", "and", "or"
    ]

    func parse(tokens: [Token]) -> (symbols: [RawSymbol], calls: [RawCall]) {
        var symbols: [RawSymbol] = []
        var calls: [RawCall] = []
        var scopes: [Scope] = []
        var braceDepth = 0

        // Depth inside (), [] and {}. Indentation only means anything at depth
        // zero: Python wraps long signatures and literals across lines, and the
        // closing bracket sits at the *declaration's* indent, which otherwise
        // reads as a dedent and closes the function before its body starts.
        var bracketDepth = 0

        let funcKeywords = language.functionKeywords
        let typeKeywords = language.typeKeywords
        let control = language.controlKeywords
        let indentScoped = language.isIndentScoped

        @inline(__always)
        func isPunct(_ idx: Int, _ ch: UInt8) -> Bool {
            idx >= 0 && idx < tokens.count && tokens[idx].kind == .punct && tokens[idx].punct == ch
        }

        @inline(__always)
        func isIdent(_ idx: Int) -> Bool {
            idx >= 0 && idx < tokens.count && tokens[idx].kind == .identifier
        }

        /// Index of the token after a balanced `( … )` starting at `open`.
        func skipParens(from open: Int) -> Int {
            guard isPunct(open, 0x28) else { return open }
            var depth = 0
            var k = open
            while k < tokens.count {
                if tokens[k].kind == .punct {
                    if tokens[k].punct == 0x28 { depth += 1 }
                    else if tokens[k].punct == 0x29 {
                        depth -= 1
                        if depth == 0 { return k + 1 }
                    }
                }
                k += 1
            }
            return tokens.count
        }

        /// Current innermost callable, for attributing call sites.
        func currentCallable() -> Int {
            for s in scopes.reversed() where s.symbolIndex >= 0 && s.kind.isCallable {
                return s.symbolIndex
            }
            return -1
        }

        func containerName() -> String? {
            for s in scopes.reversed() where s.kind == .type { return s.name }
            return nil
        }

        /// Attributes a decision point to the innermost enclosing callable.
        func noteBranch() {
            for scope in scopes.reversed() where scope.symbolIndex >= 0 && scope.kind.isCallable {
                symbols[scope.symbolIndex].branches += 1
                return
            }
        }

        func noteNesting(depth: Int) {
            for scope in scopes.reversed() where scope.symbolIndex >= 0 && scope.kind.isCallable {
                let relative = depth - scope.braceDepth
                if relative > symbols[scope.symbolIndex].maxNesting {
                    symbols[scope.symbolIndex].maxNesting = relative
                }
                return
            }
        }

        func closeScopes(downTo depth: Int, line: Int) {
            while let last = scopes.last, last.braceDepth > depth {
                if last.symbolIndex >= 0 { symbols[last.symbolIndex].endLine = line }
                scopes.removeLast()
            }
        }

        func closeIndentScopes(to indent: Int, line: Int) {
            while let last = scopes.last, last.indent >= indent {
                if last.symbolIndex >= 0 { symbols[last.symbolIndex].endLine = line }
                scopes.removeLast()
            }
        }

        var i = 0
        while i < tokens.count {
            let tok = tokens[i]

            // Indentation-scoped languages close scopes on dedent.
            if indentScoped, tok.firstOnLine, bracketDepth == 0, !scopes.isEmpty {
                closeIndentScopes(to: tok.indent, line: tok.line)
                if let scope = scopes.last, scope.symbolIndex >= 0, scope.kind.isCallable {
                    let relative = max(0, (tok.indent - scope.indent) / 4)
                    if relative > symbols[scope.symbolIndex].maxNesting {
                        symbols[scope.symbolIndex].maxNesting = relative
                    }
                }
            }

            if tok.kind == .punct {
                switch tok.punct {
                case 0x28, 0x5B: bracketDepth += 1                 // ( [
                case 0x29, 0x5D: bracketDepth = max(0, bracketDepth - 1)
                default: break
                }

                if tok.punct == 0x7B {            // {
                    braceDepth += 1
                    if indentScoped { bracketDepth += 1 }
                    noteNesting(depth: braceDepth)
                } else if tok.punct == 0x7D {     // }
                    braceDepth -= 1
                    if indentScoped { bracketDepth = max(0, bracketDepth - 1) }
                    closeScopes(downTo: braceDepth, line: tok.line)
                } else if tok.punct == 0x26 || tok.punct == 0x7C {
                    // && and || each add a path; count the pair once.
                    if isPunct(i + 1, tok.punct) {
                        noteBranch()
                        i += 2
                        continue
                    }
                }
                i += 1
                continue
            }

            guard tok.kind == .identifier else { i += 1; continue }
            let word = tok.text

            if Self.decisionWords.contains(word) { noteBranch() }

            // ---- Type / container declarations -------------------------------
            if typeKeywords.contains(word), isIdent(i + 1) {
                var nameIdx = i + 1
                // Rust `impl Trait for Type` — the meaningful name is the last one.
                if language == .rust && word == "impl" {
                    var k = i + 1
                    while isIdent(k) || isPunct(k, 0x3C) || isPunct(k, 0x3E) || isPunct(k, 0x2C) {
                        if isIdent(k) { nameIdx = k }
                        k += 1
                    }
                }
                let name = tokens[nameIdx].text
                symbols.append(RawSymbol(name: name, container: containerName(), kind: .type,
                                         language: language, fileIndex: fileIndex,
                                         line: tok.line, endLine: tok.line))
                scopes.append(Scope(name: name, kind: .type, symbolIndex: symbols.count - 1,
                                    braceDepth: braceDepth + (indentScoped ? 0 : 1),
                                    indent: tok.indent))
                i = nameIdx + 1
                continue
            }

            // ---- Keyword-introduced functions --------------------------------
            if funcKeywords.contains(word) {
                var nameIdx = i + 1

                // Go method receivers: func (r *T) Name(
                if language == .go, isPunct(i + 1, 0x28) {
                    nameIdx = skipParens(from: i + 1)
                }

                // Swift `init` / `deinit` / `subscript` are their own names.
                let isSelfNamed = (language == .swift && word != "func")
                let name: String
                if isSelfNamed {
                    name = word
                } else if isIdent(nameIdx) {
                    name = tokens[nameIdx].text
                } else {
                    i += 1
                    continue
                }

                let container = containerName()
                let kind: SymbolKind = isSelfNamed ? .initializer
                                     : (container != nil ? .method : .function)
                symbols.append(RawSymbol(name: name, container: container, kind: kind,
                                         language: language, fileIndex: fileIndex,
                                         line: tok.line, endLine: tok.line))
                scopes.append(Scope(name: name, kind: kind, symbolIndex: symbols.count - 1,
                                    braceDepth: braceDepth + (indentScoped ? 0 : 1),
                                    indent: tok.indent))
                i = isSelfNamed ? i + 1 : nameIdx + 1
                continue
            }

            // ---- JS/TS declaration forms ------------------------------------
            // JavaScript spells "function" half a dozen ways, and missing them
            // makes a large JS project look nearly empty. Handled here:
            //   const f = (…) => …        exports.f = function …
            //   f: function (…)           f: (…) => …
            //   X.prototype.f = function  { f(…) { … } }   (shorthand method)
            if language == .javascript || language == .typescript {
                var declaredName: String? = nil
                var resumeAt = i

                // const/let/var name = (…) =>  |  = function
                if (word == "const" || word == "let" || word == "var"),
                   isIdent(i + 1), isPunct(i + 2, 0x3D) {
                    if isIdent(i + 3), tokens[i + 3].text == "function" {
                        declaredName = tokens[i + 1].text
                        resumeAt = i + 4
                    } else if isIdent(i + 3), tokens[i + 3].text == "async" {
                        declaredName = tokens[i + 1].text
                        resumeAt = i + 4
                    } else {
                        let after = isPunct(i + 3, 0x28) ? skipParens(from: i + 3) : i + 4
                        if isPunct(after, 0x3D) && isPunct(after + 1, 0x3E) {
                            declaredName = tokens[i + 1].text
                            resumeAt = after + 2
                        }
                    }
                }

                // name = function …   (covers exports.name = function, X.prototype.name = …)
                if declaredName == nil, isPunct(i + 1, 0x3D), isIdent(i + 2) {
                    let rhs = tokens[i + 2].text
                    if rhs == "function" || rhs == "async" {
                        declaredName = word
                        resumeAt = i + 3
                    }
                }

                // name: function …  |  name: (…) =>
                if declaredName == nil, isPunct(i + 1, 0x3A) {
                    if isIdent(i + 2), tokens[i + 2].text == "function" || tokens[i + 2].text == "async" {
                        declaredName = word
                        resumeAt = i + 3
                    } else if isPunct(i + 2, 0x28) {
                        let after = skipParens(from: i + 2)
                        if isPunct(after, 0x3D) && isPunct(after + 1, 0x3E) {
                            declaredName = word
                            resumeAt = after + 2
                        }
                    }
                }

                // Shorthand method inside an object or class body: `name(args) {`.
                // Distinguished from a call by what precedes it — a call never
                // follows `{`, `,`, `;` or `}`.
                if declaredName == nil, isPunct(i + 1, 0x28), !control.contains(word) {
                    let after = skipParens(from: i + 1)
                    if isPunct(after, 0x7B) {
                        let prevOK: Bool
                        if i == 0 { prevOK = true }
                        else if tokens[i - 1].kind == .punct {
                            let p = tokens[i - 1].punct
                            prevOK = (p == 0x7B || p == 0x2C || p == 0x3B || p == 0x7D)
                        } else if tokens[i - 1].kind == .identifier {
                            let prev = tokens[i - 1].text
                            prevOK = (prev == "async" || prev == "get" || prev == "set" || prev == "static")
                        } else { prevOK = false }
                        if prevOK {
                            declaredName = word
                            resumeAt = after
                        }
                    }
                }

                if let name = declaredName {
                    let container = containerName()
                    let kind: SymbolKind = container != nil ? .method : .function
                    symbols.append(RawSymbol(name: name, container: container,
                                             kind: kind, language: language,
                                             fileIndex: fileIndex,
                                             line: tok.line, endLine: tok.line))
                    scopes.append(Scope(name: name, kind: kind,
                                        symbolIndex: symbols.count - 1,
                                        braceDepth: braceDepth + 1, indent: tok.indent))
                    i = resumeAt
                    continue
                }
            }

            // ---- C-family shape: Type name(args) {  ---------------------------
            if funcKeywords.isEmpty, isPunct(i + 1, 0x28), !control.contains(word) {
                let afterParens = skipParens(from: i + 1)
                var j = afterParens
                // Allow trailing qualifiers: const, noexcept, override, throws …
                while isIdent(j) && Language.cTypeNoise.contains(tokens[j].text) { j += 1 }
                if isPunct(j, 0x7B), isIdent(i - 1) || isPunct(i - 1, 0x2A) {
                    let container = containerName()
                    symbols.append(RawSymbol(name: word, container: container,
                                             kind: container != nil ? .method : .function,
                                             language: language, fileIndex: fileIndex,
                                             line: tok.line, endLine: tok.line))
                    scopes.append(Scope(name: word,
                                        kind: container != nil ? .method : .function,
                                        symbolIndex: symbols.count - 1,
                                        braceDepth: braceDepth + 1, indent: tok.indent))
                    i = j
                    continue
                }
            }

            // ---- Call sites ---------------------------------------------------
            if isPunct(i + 1, 0x28), !control.contains(word), !typeKeywords.contains(word),
               !funcKeywords.contains(word) {
                var receiver: String?
                if isPunct(i - 1, 0x2E), isIdent(i - 2) {   // foo.bar(
                    receiver = tokens[i - 2].text
                }
                calls.append(RawCall(calleeName: word, receiver: receiver,
                                     callerSymbol: currentCallable(),
                                     fileIndex: fileIndex, line: tok.line))
            }

            i += 1
        }

        // Close anything still open at EOF.
        let lastLine = tokens.last?.line ?? 1
        for s in scopes where s.symbolIndex >= 0 {
            if symbols[s.symbolIndex].endLine <= symbols[s.symbolIndex].line {
                symbols[s.symbolIndex].endLine = lastLine
            }
        }

        return (symbols, calls)
    }
}
