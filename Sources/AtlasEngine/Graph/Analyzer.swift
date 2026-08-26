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

        enum Stage: Sendable { case scanning, parsing, resolving, done }
    }

    struct Options: Sendable {
        var includeExternal: Bool = false
        var includeTests: Bool = true
    }

    /// Gathers every source file under `directory`, pruning as it goes.
    ///
    /// Written as a plain recursion rather than using `FileManager`'s
    /// enumerator, which offers `skipDescendants()` for exactly this. That
    /// call does not mean the same thing on every platform: on Windows it
    /// prunes past the directory it was asked about, and a scan of this
    /// repository came back with twelve files out of seventy-three — whole
    /// directories missing, no error, just a smaller project. Pointing the
    /// engine at any one of those directories found them all, which is what
    /// gave the pruning away.
    ///
    /// Recursing by hand is a dozen lines, prunes exactly what it is told to,
    /// and reads the same everywhere.
    private static func collect(directory: URL,
                                rootPath: String,
                                options: Options,
                                into paths: inout [(url: URL, relative: String, language: Language)]) {
        guard paths.count < maxFiles else { return }

        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]) else { return }

        for url in entries {
            guard paths.count < maxFiles else { return }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])

            if values?.isDirectory == true {
                guard !skippedDirectories.contains(url.lastPathComponent) else { continue }
                collect(directory: url, rootPath: rootPath, options: options, into: &paths)
                continue
            }

            guard let language = Language.detect(path: url.path) else { continue }
            if let size = values?.fileSize, size > maxFileBytes { continue }

            var relative = P.normalize(url.standardizedFileURL.path)
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

    // MARK: - Entry point

    static func analyze(root: URL,
                        options: Options = Options(),
                        progress: @escaping @Sendable (Progress) -> Void) -> CodeGraph {

        let started = Date()
        progress(Progress(stage: .scanning, current: 0, total: 0))

        // ---- 1. Collect candidate files ---------------------------------
        var paths: [(url: URL, relative: String, language: Language)] = []
        let rootPath = P.normalize(root.standardizedFileURL.path)

        collect(directory: root, rootPath: rootPath, options: options, into: &paths)

        guard !paths.isEmpty else {
            progress(Progress(stage: .done, current: 0, total: 0))
            var empty = CodeGraph()
            empty.rootPath = rootPath
            empty.projectName = root.lastPathComponent
            return empty
        }

        // Collection is finished. Binding it immutably lets the compiler see
        // that the parallel pass below only reads.
        //
        // Sorted, because the order files arrive in is the filesystem's
        // business and not ours — APFS, NTFS and ext4 each answer
        // differently, and that order becomes every file index in the graph.
        // Without this the same project analysed on Windows and on macOS
        // produces two reports that mean the same thing and match nowhere.
        let scanned = paths.sorted { $0.relative < $1.relative }

        // ---- 2. Parse in parallel ---------------------------------------
        progress(Progress(stage: .parsing, current: 0, total: scanned.count))

        let box = ResultBox(count: scanned.count)
        let counter = Counter()

        DispatchQueue.concurrentPerform(iterations: scanned.count) { index in
            let entry = scanned[index]
            guard let data = try? Data(contentsOf: entry.url),
                  let raw = String(data: data, encoding: .utf8)
                         ?? String(data: data, encoding: .isoLatin1) else {
                let done = counter.increment()
                if done % 64 == 0 { progress(Progress(stage: .parsing, current: done, total: scanned.count)) }
                return
            }

            // Every line-ending shape becomes `\n` before anything reads
            // the text, so the line counting and scanning below can go on
            // comparing against `"\n"` and mean it.
            let source = raw.normalizedLineEndings

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
                progress(Progress(stage: .parsing, current: done, total: scanned.count))
            }
        }

        // ---- 3. Resolve -------------------------------------------------
        progress(Progress(stage: .resolving, current: scanned.count, total: scanned.count))

        let results = box.collect(defaultPaths: scanned.map { ($0.relative, $0.language) })
        var graph = GraphBuilder.build(from: results,
                                       rootPath: rootPath,
                                       projectName: root.lastPathComponent,
                                       includeExternal: options.includeExternal)
        graph.parseSeconds = Date().timeIntervalSince(started)
        progress(Progress(stage: .done, current: scanned.count, total: scanned.count))
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
