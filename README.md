<div align="center">

# Xarita

**See the shape of a codebase.**

A native macOS app that reads a project and draws the map your editor never shows you —
which functions call which, where everything converges, and what nothing reaches at all.

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black)]()
[![Language](https://img.shields.io/badge/Swift-6.3-orange)]()
[![Architecture](https://img.shields.io/badge/Apple%20Silicon-arm64-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

[O'zbekcha →](README.uz.md)

</div>

---

## The problem

Your editor shows you **files**. But code doesn't run as files — it runs as a **graph**.

A file tree tells you how one developer chose to arrange things on disk. It tells you nothing
about what actually calls what. So every time you open an unfamiliar project you rebuild that
graph by hand, in your head, one `go to definition` at a time — and human working memory holds
about seven things.

This tool existed once. It was called [Sourcetrail](https://github.com/CoatiSoftware/Sourcetrail),
developers loved it, and it was discontinued in 2021. Nothing native replaced it on macOS.

**Xarita is that idea, rebuilt for Apple Silicon.**

---

## What it answers

| Question | How Xarita answers it |
|---|---|
| *I cloned a big project and I'm lost.* | The map shows the shape instantly — entry points, the dense core, and the 80% that's leaf nodes you can ignore. |
| *How did execution reach this function?* | Reverse call graph, several levels deep, in one click. No grepping. |
| *If I change this, what breaks?* | Blast radius — everything downstream, highlighted. |
| *Is this code still used?* | Functions nothing calls appear as visually isolated islands. |

---

## Benchmarks

Measured on a **MacBook Air M4 (16 GB)** — the smallest current Apple Silicon machine — with an
optimised (`-O`) build. Parse time covers scanning, tokenising, parsing and cross-file resolution.

| Project | Language | Files | Lines | Symbols | Call edges | Parse time |
|---|---|--:|--:|--:|--:|--:|
| [redis](https://github.com/redis/redis) | C | 333 | 241,121 | 8,359 | 20,622 | **0.05 s** |
| [express](https://github.com/expressjs/express) | JavaScript | 141 | 21,616 | 335 | 255 | 0.02 s |
| [flask](https://github.com/pallets/flask) | Python | 83 | 18,428 | 1,622 | 1,283 | 0.01 s |

Layout holds **7.4 ms per iteration at 8,359 nodes** — roughly 135 fps — thanks to Barnes–Hut
approximation.

### Sanity check

The numbers only matter if the answers are right. Asked for the most-called functions in Redis,
Xarita returns:

```
sdslen      476 callers    src/sds.h:98
sdsfree     423 callers    src/sds.c:221
zfree       370 callers    src/zmalloc.c:585
zmalloc     273 callers    src/zmalloc.c:284
sdsempty    201 callers    src/sds.c:205
```

Redis's string library and allocator — which is exactly what anyone familiar with the codebase
would name. In Flask it surfaces `Scaffold.route`, `Flask.url_for` and `render_template`; in
Express, `res.send` and `app.set`.

---

## How it works

```mermaid
flowchart LR
    A[Directory walk] --> B[Tokenizer]
    B --> C[Parser]
    C --> D[Graph builder]
    D --> E[Barnes–Hut layout]
    E --> F[Canvas]

    style A fill:#1e293b,stroke:#475569,color:#e2e8f0
    style B fill:#1e293b,stroke:#475569,color:#e2e8f0
    style C fill:#1e293b,stroke:#475569,color:#e2e8f0
    style D fill:#1e293b,stroke:#475569,color:#e2e8f0
    style E fill:#1e293b,stroke:#475569,color:#e2e8f0
    style F fill:#1e293b,stroke:#475569,color:#e2e8f0
```

**1 · Tokenizer** — a byte-level lexer working directly on UTF-8 rather than `Character`s, because
code is overwhelmingly ASCII and grapheme breaking is wasted work on files that run to hundreds of
thousands of lines. It consumes comments and string bodies so a `(` inside a string literal can
never fabricate a call, and it handles nested block comments, triple-quoted strings and template
literals per language.

**2 · Parser** — a *shape* parser rather than a type checker. It recognises the syntactic form of a
declaration (`func name(`, `def name(`, `Type name(args) {`, `name: function`, Go receivers, Rust
`impl` blocks, JS arrow assignments) and the `name(` form of a call, tracking scope through brace
depth or indentation depending on the language.

**3 · Graph builder** — resolves each call to a declaration using scope-aware name matching. Given
`foo.bar()` it prefers a method `bar` on a type named `foo`, then one in the caller's own type, then
the same file, then a unique match anywhere. Unresolved names optionally become external nodes, so
third-party and standard-library usage stays visible instead of silently vanishing.

**4 · Layout** — force-directed placement where nodes repel, edges act as springs, and the system
cools until it settles. The naive form is O(n²) per step and falls apart past a couple of thousand
nodes; Xarita builds a **Barnes–Hut quadtree** each step, approximating any cluster far enough away
(`size / distance < θ`) by its centre of mass. That brings each step to O(n log n) and keeps a
twenty-thousand-node graph interactive. Nodes are seeded on a phyllotaxis spiral grouped by file,
which converges far faster than a cold random start.

### Why a shape parser

A full compiler front-end per language would be more precise, and would also mean shipping and
maintaining thirteen of them. The trade Xarita makes — and the one Sourcetrail made for its lighter
indexers — buys three things that matter more for reading code:

- it works on a codebase that **doesn't compile**, or is missing its dependencies
- it works on **thirteen languages** from one implementation
- it parses **a quarter-million lines in 50 ms**

The cost is precision on overloads and dynamic dispatch. See [Limitations](#limitations).

---

## Supported languages

Swift · Python · JavaScript · TypeScript · C · C++ · Go · Java · Rust · Ruby · C# · PHP · Kotlin

Adding one means adding a case to `Language.swift` — the lexical rules and declaration shapes live
there, and nothing else in the pipeline changes.

---

## Status

| Component | State |
|---|---|
| Build pipeline — bundle, ad-hoc sign, launch | ✅ Working |
| Tokenizer, parser, graph resolution | ✅ Working, benchmarked |
| Barnes–Hut layout | ✅ Working, benchmarked |
| Design system, bilingual UI (uz/en) | 🚧 In progress |
| Interactive canvas | 🚧 In progress |
| Source pane, search, inspector | ⬜ Planned |
| Notification Center widget | ⬜ Planned |
| Notifications | ⬜ Planned |
| Signed `.dmg` | ⬜ Planned |

---

## Building

Requires macOS 14+ on Apple Silicon and the Xcode Command Line Tools. Full Xcode is **not** needed.

```bash
xcode-select --install
```

```bash
git clone https://github.com/<you>/xarita.git && cd xarita && ./Scripts/build.sh
```

The build writes to `~/Library/Caches/uz.xarita.build` rather than into the repo. That is
deliberate: this project is developed in an iCloud-synced folder, and iCloud stamps
`com.apple.FinderInfo` onto files, which makes `codesign` fail with *"resource fork, Finder
information, or similar detritus not allowed."* Building outside the synced tree avoids it entirely.

---

## Limitations

Stated plainly, because a tool that overstates what it knows is worse than one that doesn't:

- **Name-based resolution.** Two different functions with the same name may be merged, and calls
  through function pointers, decorators, reflection or a router are invisible.
- **"Unreachable" means *suspicious*, not *dead*.** A zero fan-in is a hint. Framework callbacks and
  dynamically dispatched entry points legitimately have no visible callers, so test files, example
  directories and entry-point-shaped names are excluded from the list — but you still have to check.
- **No type inference.** `a.render()` and `b.render()` resolve by name and scope heuristics, not by
  knowing the types of `a` and `b`.
- **Ad-hoc signed.** Distribution builds are signed with `codesign -s -`, so Gatekeeper will warn on
  first launch until the app is notarised with a paid Developer ID.

---

## Why "Xarita"

*Xarita* is Uzbek for **map**. The app's interface ships in Uzbek and English.

---

## License

MIT
