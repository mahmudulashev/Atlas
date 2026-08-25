import Foundation

// Atlas's analysis engine, without a window.
//
// The macOS app links this code directly. Windows cannot — SwiftUI does not
// exist there — so the same engine runs here as a batch process and hands its
// finished picture to whatever draws it, as one JSON document. That keeps the
// parser and the graph a single source of truth across both platforms; only
// the drawing is written twice.

let usage = """
atlas-engine — Atlas's code analysis engine, headless.

USAGE
  atlas-engine analyze <path> [options]
  atlas-engine version
  atlas-engine help

OPTIONS
  --out <file>         Write JSON to a file instead of stdout.
  --pretty             Indent the JSON. Larger, but readable.
  --lang <uz|en>       Language for titles and labels. Default: en.
  --include-external   Keep unresolved symbols the project calls but does
                       not define.
  --no-tests           Skip test files while scanning.
  --tests-in-diagram   Let test files appear in the Map.
  --no-layout          Skip the Map layout. Smaller and faster when the
                       caller only wants figures.
  --no-drift           Do not compare against the previous scan, and do not
                       record this one.
  --progress           Report progress on stderr, one JSON object per line.

EXIT
  0  analysed
  1  bad usage
  2  nothing to analyse
"""

// MARK: - Output helpers

/// stderr, unbuffered enough to interleave sensibly with a progress stream.
func note(_ line: String) {
    fputs(line + "\n", stderr)
}

func fail(_ message: String, code: Int32) -> Never {
    note("atlas-engine: \(message)")
    exit(code)
}

// MARK: - Arguments

var arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    note(usage)
    exit(1)
}
arguments.removeFirst()

switch command {
case "version", "--version", "-v":
    print("atlas-engine 1.0 (schema \(Report.schema))")
    exit(0)
case "help", "--help", "-h":
    print(usage)
    exit(0)
case "analyze":
    break
default:
    fail("unknown command '\(command)'. Try 'atlas-engine help'.", code: 1)
}

var target: String?
var outputPath: String?
var pretty = false
var language = AppLanguage.en
var includeExternal = false
var includeTests = true
var testsInDiagram = false
var wantLayout = true
var wantDrift = true
var emitProgress = false

var index = 0
while index < arguments.count {
    let argument = arguments[index]
    func value(_ name: String) -> String {
        index += 1
        guard index < arguments.count else { fail("\(name) needs a value", code: 1) }
        return arguments[index]
    }

    switch argument {
    case "--out":               outputPath = value("--out")
    case "--pretty":            pretty = true
    case "--lang":
        let raw = value("--lang")
        guard let parsed = AppLanguage(rawValue: raw) else {
            fail("--lang must be 'uz' or 'en', not '\(raw)'", code: 1)
        }
        language = parsed
    case "--include-external":  includeExternal = true
    case "--no-tests":          includeTests = false
    case "--tests-in-diagram":  testsInDiagram = true
    case "--no-layout":         wantLayout = false
    case "--no-drift":          wantDrift = false
    case "--progress":          emitProgress = true
    default:
        if argument.hasPrefix("-") { fail("unknown option '\(argument)'", code: 1) }
        if target != nil { fail("more than one path given", code: 1) }
        target = argument
    }
    index += 1
}

guard let target else { fail("analyze needs a path. Try 'atlas-engine help'.", code: 1) }

let root = URL(fileURLWithPath: P.system(target), isDirectory: true).standardizedFileURL
var isDirectory: ObjCBool = false
guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
    fail("no such directory: \(target)", code: 1)
}
guard isDirectory.boolValue else { fail("not a directory: \(target)", code: 1) }

// MARK: - Analyse

@Sendable func name(_ stage: Analyzer.Progress.Stage) -> String {
    switch stage {
    case .scanning:  return "scanning"
    case .parsing:   return "parsing"
    case .resolving: return "resolving"
    case .laying:    return "laying"
    case .done:      return "done"
    }
}

let graph = Analyzer.analyze(
    root: root,
    options: Analyzer.Options(includeExternal: includeExternal, includeTests: includeTests)
) { progress in
    guard emitProgress else { return }
    // Hand-written rather than encoded: this runs on every parsed file from
    // several threads at once, and a JSONEncoder per tick would cost more
    // than the parsing it reports on.
    note("""
    {"stage":"\(name(progress.stage))","current":\(progress.current),"total":\(progress.total)}
    """)
}

guard !graph.nodes.isEmpty else {
    fail("found no source Atlas can read in \(root.path)", code: 2)
}

// The same order the app uses: the file graph feeds both the Map and the
// issue finder, and drift compares against it.
let fileGraph = FileGraph.build(from: graph, includeTests: testsInDiagram)
let layout = wantLayout ? DiagramLayout(graph: fileGraph) : nil
let issues = IssueFinder.find(graph: graph, fileGraph: fileGraph)
let route = Route.build(from: graph)
let kind = ProjectKind.heuristic(for: graph)

// Drift compares this scan with the last, then becomes the last. Order
// matters: record first and every project looks unchanged.
var drift: Drift?
if wantDrift {
    let current = DriftStore.record(from: graph, fileGraph: fileGraph)
    if let previous = DriftStore.load(projectPath: graph.rootPath) {
        drift = DriftStore.compare(previous: previous, current: current)
    } else {
        drift = Drift()
    }
    DriftStore.save(current, projectPath: graph.rootPath)
}

let report = Report.build(graph: graph,
                          fileGraph: fileGraph,
                          layout: layout,
                          issues: issues,
                          route: route,
                          kind: kind,
                          drift: drift,
                          language: language)

// MARK: - Emit

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                                  : [.withoutEscapingSlashes]

let data: Data
do {
    data = try encoder.encode(report)
} catch {
    fail("could not encode the report: \(error)", code: 2)
}

if let outputPath {
    let destination = URL(fileURLWithPath: P.system(outputPath))
    do {
        try data.write(to: destination, options: .atomic)
    } catch {
        fail("could not write \(outputPath): \(error)", code: 2)
    }
    note("✓ \(graph.nodes.count) symbols, \(graph.edges.count) connections → \(outputPath)")
} else {
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
}
