import Foundation

/// Path arithmetic that gives the same answer on macOS and Windows.
///
/// `NSString`'s path helpers are POSIX-flavoured, and on Windows the
/// corelibs implementation does not agree with the platform about
/// separators. Since every heuristic in the graph reads paths as text —
/// looking for `"src/"`, `"/test"`, a `.swift` suffix — a disagreement
/// there silently changes analysis results rather than crashing.
///
/// So the rules are fixed here instead of borrowed:
///
/// * Every path the graph stores is **relative to the project root and
///   separated by `/`**, on both platforms. `Analyzer` folds backslashes on
///   the way in, which is why `path.contains("/test")` keeps working when
///   the same project is scanned from `C:\src\app`.
/// * `system` converts back, and is used only where a path meets the
///   filesystem.
enum P {

    // MARK: - Separators

    /// Folds Windows separators to `/` so stored paths are platform-neutral.
    static func normalize(_ path: String) -> String {
        path.contains("\\") ? path.replacingOccurrences(of: "\\", with: "/") : path
    }

    /// The form the filesystem expects. Only for paths about to be opened.
    static func system(_ path: String) -> String {
        #if os(Windows)
        return path.replacingOccurrences(of: "/", with: "\\")
        #else
        return path
        #endif
    }

    /// A `URL` for a stored (forward-slash) path.
    static func url(_ path: String) -> URL {
        URL(fileURLWithPath: system(path))
    }

    // MARK: - Components

    /// Collapses repeated separators and drops a trailing one, which is what
    /// `NSString`'s path helpers do before answering. Matching it matters:
    /// the macOS app must keep classifying files exactly as it did.
    private static func clean(_ path: String) -> String {
        var p = normalize(path)
        while p.contains("//") { p = p.replacingOccurrences(of: "//", with: "/") }
        while p.count > 1, p.hasSuffix("/") { p.removeLast() }
        return p
    }

    /// `"a/b/c.swift"` → `"c.swift"`. Trailing separators are ignored.
    static func lastComponent(_ path: String) -> String {
        let p = clean(path)
        guard p != "/" else { return "/" }
        guard let slash = p.lastIndex(of: "/") else { return p }
        return String(p[p.index(after: slash)...])
    }

    /// `"a/b/c.swift"` → `"a/b"`. A bare filename yields `""`.
    static func deletingLastComponent(_ path: String) -> String {
        let p = clean(path)
        guard let slash = p.lastIndex(of: "/") else { return "" }
        if slash == p.startIndex { return "/" }
        return String(p[p.startIndex..<slash])
    }

    /// `"c.swift"` → `"swift"`. A leading dot marks a hidden file rather than
    /// an extension, so `".gitignore"` yields `""` — and so does a bare
    /// trailing dot, as in `"index."`.
    static func pathExtension(_ path: String) -> String {
        let name = lastComponent(path)
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return String(name[name.index(after: dot)...])
    }

    /// `"a/b/c.swift"` → `"a/b/c"`. Leaves the path alone when there is no
    /// extension to remove, so `"index."` keeps its dot.
    static func deletingExtension(_ path: String) -> String {
        let p = clean(path)
        let ext = pathExtension(p)
        guard !ext.isEmpty else { return p }
        return String(p.dropLast(ext.count + 1))
    }

    /// Joins with exactly one separator, whatever the ends look like.
    static func join(_ base: String, _ component: String) -> String {
        let b = normalize(base)
        let c = normalize(component)
        if b.isEmpty { return c }
        if c.isEmpty { return b }
        let trimmedBase = b.hasSuffix("/") ? String(b.dropLast()) : b
        let trimmedPart = c.hasPrefix("/") ? String(c.dropFirst()) : c
        return trimmedBase + "/" + trimmedPart
    }

    // MARK: - Standardising

    /// Resolves `.` and `..` textually, without touching the disk.
    ///
    /// Deliberately lexical: this is used to key a lookup table of files the
    /// analyzer has already seen, so it must agree with the paths recorded
    /// during the walk. Resolving symlinks here would make an import
    /// resolve to a path that is not in the table.
    static func standardizing(_ path: String) -> String {
        let p = normalize(path)
        guard p.contains("./") || p.hasSuffix("/.") || p.hasSuffix("/..") || p.contains("//") else {
            return p.count > 1 && p.hasSuffix("/") ? String(p.dropLast()) : p
        }

        let absolute = p.hasPrefix("/")
        var resolved: [String] = []
        for part in p.split(separator: "/", omittingEmptySubsequences: true) {
            switch part {
            case ".":
                continue
            case "..":
                // A leading `..` on a relative path has nothing to pop and
                // must survive, or `../shared/util` collapses to `shared/util`
                // and resolves against the wrong directory.
                if let last = resolved.last, last != ".." {
                    resolved.removeLast()
                } else if !absolute {
                    resolved.append("..")
                }
            default:
                resolved.append(String(part))
            }
        }
        let joined = resolved.joined(separator: "/")
        if absolute { return "/" + joined }
        return joined
    }

    /// True when the path is rooted — `/usr/lib` or `C:/src`.
    static func isAbsolute(_ path: String) -> Bool {
        let p = normalize(path)
        if p.hasPrefix("/") { return true }
        // Windows drive letter, e.g. `C:/…`
        var chars = p.makeIterator()
        guard let first = chars.next(), first.isLetter, chars.next() == ":" else { return false }
        return true
    }
}
