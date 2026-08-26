#!/bin/bash
# Assembles a release: the client, the engine, and nothing else.
#
#   Scripts/package.sh windows [output-dir]
#   Scripts/package.sh linux   [output-dir]
#
# One script for both, because two would drift. The engine is Swift and does
# not cross-compile, so each package can only be built on the platform it is
# for.
set -euo pipefail

cd "$(dirname "$0")/.."

PLATFORM="${1:-}"
case "$PLATFORM" in
  windows) RID=win-x64;   EXE=.exe ;;
  linux)   RID=linux-x64; EXE=     ;;
  *) echo "usage: Scripts/package.sh <windows|linux> [output-dir]" >&2; exit 1 ;;
esac

OUT="${2:-dist/Atlas-$PLATFORM-x64}"
CLIENT="Windows/Atlas.Windows"

echo "▸ Engine"
swift build -c release
ENGINE=".build/release/atlas-engine$EXE"
[ -f "$ENGINE" ] || { echo "no engine at $ENGINE — did swift build run?" >&2; exit 1; }

echo "▸ Client"
dotnet publish "$CLIENT" -c Release -r "$RID" -o "$OUT" -v q --nologo

# Native debug symbols ride along with SkiaSharp and HarfBuzz and are a
# hundred megabytes of nothing a user needs. DebugType=none only covers ours.
find "$OUT" -name '*.pdb' -delete

# The client looks for the engine beside itself first; see EngineRunner.Locate.
cp "$ENGINE" "$OUT/atlas-engine$EXE"
chmod +x "$OUT/atlas-engine$EXE" "$OUT/Atlas$EXE" 2>/dev/null || true

if [ "$PLATFORM" = windows ]; then
  STORE='%LOCALAPPDATA%\Atlas'
else
  STORE='~/.local/share/Atlas'
fi

cat > "$OUT/README.txt" <<TXT
Atlas — read a codebase you have never seen.

Run Atlas$EXE. Choose a folder. That is the whole setup.

Two files matter here:

  Atlas$EXE          the app
  atlas-engine$EXE   the analysis, which the app runs as a separate program

Keep them together. atlas-engine is the same code the macOS build of Atlas
uses, so every version reads a project identically — you can check that
yourself: \`atlas-engine$EXE analyze <folder> --pretty\` prints everything the
app draws.

No installer, no runtime to fetch, and nothing written outside $STORE, where
Atlas keeps the scan history that lets it tell you what moved since last time.

MIT licensed. https://github.com/mahmudulashev/Atlas
TXT

echo "▸ Contents:"
ls -1 "$OUT" | sed 's/^/    /'
echo "▸ Size    : $(du -sh "$OUT" | cut -f1)"
echo "✓ Packaged $OUT"
