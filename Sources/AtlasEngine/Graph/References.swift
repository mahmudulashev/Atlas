import Foundation

/// Finds the paths one file names in another.
///
/// Call-graph edges only appear where one function calls another, which misses
/// the way front-end projects are actually wired: a page pulls in a stylesheet
/// and a script, a module imports a sibling. Those references are the real
/// dependencies of an HTML/CSS project — without them a static site analyses as
/// a set of unconnected islands.
enum References {

    /// Raw reference strings as written in the source, before resolution.
    static func scan(source: String, language: Language) -> [String] {
        switch language {
        case .html, .vue, .svelte:
            return attributes(in: source, names: ["src", "href"])
        case .css, .scss:
            return imports(in: source, markers: ["@import"]) + urls(in: source)
        case .javascript, .typescript:
            return imports(in: source, markers: ["from", "require(", "import("])
                 + imports(in: source, markers: ["import"])
        case .python:
            return pythonImports(in: source)
        case .c, .cpp:
            return imports(in: source, markers: ["#include"])
        default:
            return []
        }
    }

    // MARK: - Extraction

    private static func attributes(in source: String, names: [String]) -> [String] {
        var found: [String] = []
        let characters = Array(source)

        for name in names {
            let needle = Array(name + "=")
            var index = 0
            while index + needle.count < characters.count {
                defer { index += 1 }
                guard characters[index] == needle[0] else { continue }
                var matched = true
                for offset in needle.indices where characters[index + offset] != needle[offset] {
                    matched = false
                    break
                }
                guard matched else { continue }
                // Must be an attribute, not the tail of another word.
                if index > 0 {
                    let previous = characters[index - 1]
                    guard previous == " " || previous == "\t" || previous == "\n" else { continue }
                }
                var cursor = index + needle.count
                guard cursor < characters.count else { break }
                let quote = characters[cursor]
                guard quote == "\"" || quote == "'" else { continue }
                cursor += 1
                var end = cursor
                while end < characters.count, characters[end] != quote { end += 1 }
                let value = String(characters[cursor..<end])
                if isLocal(value) { found.append(value) }
                index = end
            }
        }
        return found
    }

    private static func imports(in source: String, markers: [String]) -> [String] {
        var found: [String] = []
        for line in source.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard markers.contains(where: { trimmed.contains($0) }) else { continue }
            for quote in ["\"", "'", "<"] {
                let close = quote == "<" ? ">" : quote
                guard let start = trimmed.range(of: quote),
                      let end = trimmed.range(of: close, range: start.upperBound..<trimmed.endIndex)
                else { continue }
                let value = String(trimmed[start.upperBound..<end.lowerBound])
                if isLocal(value) { found.append(value) }
                break
            }
        }
        return found
    }

    private static func urls(in source: String) -> [String] {
        var found: [String] = []
        var remainder = Substring(source)
        while let start = remainder.range(of: "url(") {
            let after = remainder[start.upperBound...]
            guard let end = after.firstIndex(of: ")") else { break }
            var value = String(after[..<end])
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            if isLocal(value) { found.append(value) }
            remainder = after[end...]
        }
        return found
    }

    /// `from .helpers import x` and `import package.module` both name a file.
    private static func pythonImports(in source: String) -> [String] {
        var found: [String] = []
        for line in source.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("from ") || trimmed.hasPrefix("import ") else { continue }
            let body = trimmed.hasPrefix("from ")
                ? String(trimmed.dropFirst(5)).components(separatedBy: " ").first ?? ""
                : String(trimmed.dropFirst(7)).components(separatedBy: " ").first ?? ""
            let module = body.trimmingCharacters(in: .whitespaces)
            guard !module.isEmpty else { continue }
            let leadingDots = module.prefix { $0 == "." }.count
            let cleaned = String(module.drop { $0 == "." })
                .replacingOccurrences(of: ".", with: "/")
            guard !cleaned.isEmpty else { continue }
            found.append(String(repeating: "../", count: max(0, leadingDots - 1)) + cleaned)
        }
        return found
    }

    private static func isLocal(_ value: String) -> Bool {
        guard !value.isEmpty, value.count < 200 else { return false }
        for prefix in ["http://", "https://", "//", "data:", "mailto:", "tel:", "#", "{"]
        where value.hasPrefix(prefix) { return false }
        return true
    }

    // MARK: - Resolution

    /// Turns a written reference into an index in the project's file list.
    ///
    /// Tries the literal path first, then the extensions and `index.*` forms a
    /// bundler would try, because source almost never spells the whole path.
    static func resolve(_ reference: String,
                        from filePath: String,
                        index: [String: Int]) -> Int? {
        let directory = (filePath as NSString).deletingLastPathComponent
        var candidates: [String] = []

        let cleaned = reference.components(separatedBy: "?").first ?? reference
        if cleaned.hasPrefix("/") {
            candidates.append(String(cleaned.dropFirst()))
        } else {
            candidates.append((directory as NSString).appendingPathComponent(cleaned))
            candidates.append(cleaned)
        }

        let extensions = ["", ".js", ".ts", ".jsx", ".tsx", ".mjs", ".css", ".scss",
                          ".sass", ".less", ".html", ".py", ".vue", ".svelte", ".h", ".hpp"]
        let indexForms = ["/index.js", "/index.ts", "/index.tsx", "/__init__.py"]

        for base in candidates {
            let normalized = (base as NSString).standardizingPath
            for ext in extensions {
                if let hit = index[normalized + ext] { return hit }
            }
            for form in indexForms {
                if let hit = index[normalized + form] { return hit }
            }
        }
        return nil
    }
}
