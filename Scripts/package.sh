#!/bin/bash
# Assembles a release: the client, the engine, and what the engine needs to
# start on a machine that has no Swift toolchain on it.
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
# Linux links the Swift runtime in. The default is to leave it dynamic, where
# it resolves through an rpath into the toolchain's own lib directory -- an
# absolute path that exists on the machine that built the package and on no
# machine that unpacks it. Windows has no equivalent flag, and carries the
# runtime beside the binary instead; see Scripts/copy-windows-runtime.py.
BUILD=(swift build -c release)
[ "$PLATFORM" = linux ] && BUILD+=(--static-swift-stdlib)
"${BUILD[@]}"
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

# On Windows the Swift runtime is a set of DLLs rather than something linked
# into the binary, and the toolchain keeps them on PATH. A package built
# without them therefore started on every machine that could have built it and
# on no machine that had only downloaded it -- which is exactly what v1.2 did.
if [ "$PLATFORM" = windows ]; then
  python Scripts/copy-windows-runtime.py "$OUT/atlas-engine.exe"
fi

# And the same question asked of Linux, where the answer should be that the
# loader has nothing left to look for: ldd names every library the engine
# needs by name, and none of them may be one the toolchain owns.
if [ "$PLATFORM" = linux ]; then
  if ldd "$OUT/atlas-engine" | grep -i swift; then
    echo "the engine still wants a Swift library from the toolchain" >&2
    exit 1
  fi
  echo "▸ Runtime : linked in, so the machine needs no Swift"
fi

if [ "$PLATFORM" = windows ]; then
  STORE='%LOCALAPPDATA%\Atlas'
  RUNTIME='The .dll files beside them are the Swift runtime the engine is built
against. They belong to this folder rather than to your system: nothing is
installed, nothing is registered, and deleting the folder removes Atlas.

'
else
  STORE='~/.local/share/Atlas'
  RUNTIME=''
fi

cat > "$OUT/README.txt" <<TXT
Atlas — read a codebase you have never seen.

Run Atlas$EXE. Choose a folder. That is the whole setup.

Two files matter here:

  Atlas$EXE          the app
  atlas-engine$EXE   the analysis, which the app runs as a separate program

${RUNTIME}Keep them together. atlas-engine is the same code the macOS build of Atlas
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
