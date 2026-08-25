import Foundation

extension String {

    /// The same text with every line ending written as a single `\n`.
    ///
    /// Swift counts `\r\n` as **one** `Character`, because it is a single
    /// extended grapheme cluster. That quietly breaks the two idioms this
    /// engine reaches for most:
    ///
    /// ```swift
    /// "a\r\nb".split(separator: "\n")            // ["a\r\nb"] — never splits
    /// "a\r\nb".reduce(0) { $1 == "\n" ? $0+1 : $0 }  // 0 — never matches
    /// ```
    ///
    /// So a Windows checkout read as-is is one enormous line: every file
    /// reports a single line, and the import scanner sees the whole file as
    /// one statement and keeps only the first module named in it. Neither
    /// failure looks like a failure — the numbers are simply wrong.
    ///
    /// Normalising once, where the bytes are read, is what keeps every
    /// `"\n"` comparison downstream meaning what it says. Lone `\r` is
    /// folded too, for files last saved by something very old.
    var normalizedLineEndings: String {
        // Checked on scalars, since `contains("\r")` would have to look
        // inside a `\r\n` cluster to find one — the same trap.
        guard unicodeScalars.contains("\r") else { return self }
        return replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
