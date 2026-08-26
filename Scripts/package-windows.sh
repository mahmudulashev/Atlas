#!/bin/bash
# Assembles the Windows release: the client, the engine, and nothing else.
#
#   Scripts/package-windows.sh [output-dir]
#
# Runs on a Windows runner under Git Bash, or anywhere with a .NET SDK for the
# client half — but the engine is Swift and does not cross-compile to Windows,
# so a complete package can only be built on Windows.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="${1:-dist/Atlas-windows-x64}"
CLIENT="Windows/Atlas.Windows"

echo "▸ Engine"
swift build -c release
ENGINE=".build/release/atlas-engine.exe"
[ -f "$ENGINE" ] || ENGINE=".build/release/atlas-engine"
[ -f "$ENGINE" ] || { echo "no engine at .build/release — did swift build run?" >&2; exit 1; }

echo "▸ Client"
dotnet publish "$CLIENT" -c Release -r win-x64 -o "$OUT" -v q --nologo

# Native debug symbols ride along with SkiaSharp and HarfBuzz and are a
# hundred megabytes of nothing a user needs. DebugType=none only covers ours.
find "$OUT" -name '*.pdb' -delete

# The client looks for the engine beside itself first; see EngineRunner.Locate.
cp "$ENGINE" "$OUT/$(basename "$ENGINE")"

cat > "$OUT/README.txt" <<'TXT'
Atlas — read a codebase you have never seen.

Run Atlas.exe. Choose a folder. That is the whole setup.

Two files matter here:

  Atlas.exe         the app
  atlas-engine.exe  the analysis, which the app runs as a separate program

Keep them together. atlas-engine is the same code the macOS build of Atlas
uses, so the two versions read a project identically -- you can check that
yourself: `atlas-engine analyze <folder> --pretty` prints everything the app
draws.

No installer, no runtime to fetch, nothing written outside your user folder.
Atlas keeps its scan history in %LOCALAPPDATA%\Atlas so it can tell you what
moved since last time.

MIT licensed. https://github.com/mahmudulashev/Atlas
TXT

SIZE=$(du -sh "$OUT" | cut -f1)
echo "▸ Contents:"
ls -1 "$OUT" | sed 's/^/    /'
echo "▸ Size    : $SIZE"
echo "✓ Packaged $OUT"
