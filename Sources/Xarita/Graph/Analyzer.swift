import Foundation

/// Walks a project directory, parses every source file it recognises, and hands
/// back a resolved graph.
///
/// Parsing is the expensive phase and is embarrassingly parallel — each file is
/// independent until resolution — so files are spread across all performance
/// cores with `concurrentPerform`. Resolution is then a single pass.
enum Analyzer {

    /// Directories never worth walking into.
    static let skippedDirectories: Set<String> = [
        ".git", ".svn", ".hg", "node_modules", "vendor", "Pods", "Carthage",
        ".build", "build", "dist", "out", "target", ".next", ".nuxt", "venv",
        ".venv", "env", "__pycache__", ".mypy_cache", ".pytest_cache", ".tox",
        "DerivedData", ".gradle", "bin", "obj", ".idea", ".vscode", "coverage",
        "third_party", "external", "deps", "Externals", ".terraform", "site-packages"
    ]

    static let maxFileBytes = 2_000_000       // skip generated monsters
    static let maxFiles = 20_000

    struct Progress: Sendable {
        var stage: Stage
        var current: Int
        var total: Int

        enum Stage: Sendable { case scanning, parsing, resolving, laying, done }
    }

    struct Options: Sendable {
        var includeExternal: Bool = false
        var includeTests: Bool = true
    }

    // MARK: - Entry point

    static func analyze(root: URL,
                        options: Options = Options(),
                        progress: @escaping @Sendable (Progress) -> Void) -> CodeGraph {

        let started = Date()
        progress(Progress(stage: .scanning, current: 0, total: 0))

        // ---- 1. Collect candidate files ---------------------------------
        var paths: [(url: URL, relative: String, language: Language)] = []
        let rootPath = root.standardizedFileURL.path
        let fm = FileManager.default

        if let walker = fm.enumerator(at: root,
                                      includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                                      options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let url as URL in walker {
                guard paths.count < maxFiles else { break }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])

                if values?.isDirectory == true {
                    if skippedDirectories.contains(url.lastPathComponent) {
                        walker.skipDescendants()
                    }
                    continue
                }
                guard let language = Language.detect(path: url.path) else { continue }
                if let size = values?.fileSize, size > maxFileBytes { continue }

                var relative = url.standardizedFileURL.path
                if relative.hasPrefix(rootPath) {
                    relative = String(relative.dropFirst(rootPath.count))
                    if relative.hasPrefix("/") { relative.removeFirst() }
                }
                if !options.includeTests {
                    let lower = relative.lowercased()
                    if lower.contains("/test") || lower.hasPrefix("test") || lower.contains("spec.") {
                        continue
                    }
                }
                paths.append((url, relative, language))
            }
        }

        guard !paths.isEmpty else {
            progress(Progress(stage: .done, current: 0, total: 0))
            var empty = CodeGraph()
            empty.rootPath = rootPath
            empty.projectName = root.lastPathComponent
            return empty
        }

        // ---- 2. Parse in parallel ---------------------------------------
        progress(Progress(stage: .parsing, current: 0, total: paths.count))

        let box = ResultBox(count: paths.count)
        let counter = Counter()

        DispatchQueue.concurrentPerform(iterations: paths.count) { index in
            let entry = paths[index]
            guard let data = try? Data(contentsOf: entry.url),
                  let source = String(data: data, encoding: .utf8)
                            ?? String(data: data, encoding: .isoLatin1) else {
                let done = counter.increment()
                if done % 64 == 0 { progress(Progress(stage: .parsing, current: done, total: paths.count)) }
                return
            }

            // Stylesheets and markup have no callables; their structure is
            // rules and named elements, so they take a different route.
            let parsed: (symbols: [RawSymbol], calls: [RawCall])
            if entry.language.isMarkupOrStyle {
                parsed = StyleParser.parse(source: source, language: entry.language,
                                           fileIndex: index)
            } else {
                let tokens = Tokenizer(source: source, language: entry.language).tokenize()
                parsed = Parser(language: entry.language, fileIndex: index).parse(tokens: tokens)
            }
            let lines = source.reduce(into: 1) { acc, ch in if ch == "\n" { acc += 1 } }

            box.set(index, GraphBuilder.FileResult(path: entry.relative,
                                                   symbols: parsed.symbols,
                                                   calls: parsed.calls,
                                                   lines: lines,
                                                   language: entry.language,
                                                   references: References.scan(
                                                       source: source,
                                                       language: entry.language)))

            let done = counter.increment()
            if done % 64 == 0 {
                progress(Progress(stage: .parsing, current: done, total: paths.count))
            }
        }

        // ---- 3. Resolve -------------------------------------------------
        progress(Progress(stage: .resolving, current: paths.count, total: paths.count))

        let results = box.collect(defaultPaths: paths.map { ($0.relative, $0.language) })
        var graph = GraphBuilder.build(from: results,
                                       rootPath: rootPath,
                                       projectName: root.lastPathComponent,
                                       includeExternal: options.includeExternal)
        graph.parseSeconds = Date().timeIntervalSince(started)
        progress(Progress(stage: .done, current: paths.count, total: paths.count))
        return graph
    }
}

/// Lock-protected slot array so parallel parse workers can write results without
/// contending on a single mutable array.
private final class ResultBox: @unchecked Sendable {
    private var storage: [GraphBuilder.FileResult?]
    private let lock = NSLock()

    init(count: Int) { storage = Array(repeating: nil, count: count) }

    func set(_ index: Int, _ value: GraphBuilder.FileResult) {
        lock.lock(); storage[index] = value; lock.unlock()
    }

    func collect(defaultPaths: [(String, Language)]) -> [GraphBuilder.FileResult] {
        lock.lock(); defer { lock.unlock() }
        return storage.enumerated().map { index, value in
            value ?? GraphBuilder.FileResult(path: defaultPaths[index].0, symbols: [], calls: [],
                                             lines: 0, language: defaultPaths[index].1)
        }
    }
}

private final class Counter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()
    func increment() -> Int { lock.lock(); value += 1; let v = value; lock.unlock(); return v }
}
