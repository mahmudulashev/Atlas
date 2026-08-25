import Foundation

/// Reads source files on demand and hands out the slice a declaration occupies.
///
/// Files are cached as line arrays because every lookup is line-based, and the
/// cache is bounded so opening a large project can't grow without limit.
final class SourceCache {

    private var files: [String: [String]] = [:]
    private var order: [String] = []
    private let limit = 60
    private let lock = NSLock()

    func lines(ofFile path: String) -> [String]? {
        lock.lock()
        if let cached = files[path] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let data = try? Data(contentsOf: P.url(path)),
              let text = String(data: data, encoding: .utf8)
                      ?? String(data: data, encoding: .isoLatin1) else { return nil }

        let split = text.normalizedLineEndings.components(separatedBy: "\n")

        lock.lock()
        files[path] = split
        order.append(path)
        if order.count > limit, let oldest = order.first {
            files.removeValue(forKey: oldest)
            order.removeFirst()
        }
        lock.unlock()
        return split
    }

    /// The source text of one declaration, with a little context above it.
    func snippet(for node: GraphNode, in graph: CodeGraph, contextLines: Int = 0)
        -> (text: String, firstLine: Int)? {
        guard node.fileIndex >= 0, node.fileIndex < graph.files.count else { return nil }
        let full = P.join(graph.rootPath, graph.files[node.fileIndex])
        guard let all = lines(ofFile: full) else { return nil }

        let start = max(0, node.line - 1 - contextLines)
        let end = min(all.count, max(node.endLine, node.line))
        guard start < end else { return nil }

        return (all[start..<end].joined(separator: "\n"), start + 1)
    }

    func absolutePath(for node: GraphNode, in graph: CodeGraph) -> String? {
        guard node.fileIndex >= 0, node.fileIndex < graph.files.count else { return nil }
        return P.join(graph.rootPath, graph.files[node.fileIndex])
    }
}
