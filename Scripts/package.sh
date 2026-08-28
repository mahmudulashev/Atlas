#!/bin/bash
# Assembles the Windows release: the client, the engine, and what the engine
# needs to start on a machine that has no Swift toolchain on it.
#
#   Scripts/package.sh [output-dir]
#
# Windows only, and only buildable on Windows: the engine is Swift and does
# not cross-compile. The macOS build has its own path, Scripts/make-dmg.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-dist/Atlas-windows-x64}"
CLIENT="Windows/Atlas.Windows"

echo "▸ Engine"
swift build -c release
ENGINE=".build/release/atlas-engine.exe"
[ -f "$ENGINE" ] || { echo "no engine at $ENGINE — did swift build run?" >&2; exit 1; }

echo "▸ Client"
dotnet publish "$CLIENT" -c Release -r win-x64 -o "$OUT" -v q --nologo

# Native debug symbols ride along with SkiaSharp and HarfBuzz and are a
# hundred megabytes of nothing a user needs. DebugType=none only covers ours.
find "$OUT" -name '*.pdb' -delete

# The client looks for the engine beside itself first; see EngineRunner.Locate.
cp "$ENGINE" "$OUT/atlas-engine.exe"

# The Swift runtime on Windows is a set of DLLs rather than something linked
# into the binary, and the toolchain keeps them on PATH. A package built
# without them therefore started on every machine that could have built it and
# on no machine that had only downloaded it -- which is exactly what v1.2 did.
echo "▸ Runtime"
python Scripts/copy-windows-runtime.py "$OUT/atlas-engine.exe"

cat > "$OUT/README.txt" <<TXT
Atlas — read a codebase you have never seen.

Run Atlas.exe. Choose a folder. That is the whole setup.

Two files matter here:

  Atlas.exe          the app
  atlas-engine.exe   the analysis, which the app runs as a separate program

The .dll files beside them are the Swift runtime the engine is built
against. They belong to this folder rather than to your system: nothing is
installed, nothing is registered, and deleting the folder removes Atlas.

Keep them together. atlas-engine is the same code the macOS build of Atlas
uses, so both versions read a project identically — you can check that
yourself: \`atlas-engine.exe analyze <folder> --pretty\` prints everything the
app draws.

No installer, no runtime to fetch, and nothing written outside
%LOCALAPPDATA%\Atlas, where Atlas keeps the scan history that lets it tell you
what moved since last time.

MIT licensed. https://github.com/mahmudulashev/Atlas
TXT

echo "▸ Contents:"
ls -1 "$OUT" | sed 's/^/    /'
echo "▸ Size    : $(du -sh "$OUT" | cut -f1)"
echo "✓ Packaged $OUT"
