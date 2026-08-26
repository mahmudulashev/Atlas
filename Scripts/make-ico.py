#!/usr/bin/env python3
"""Builds Resources/AppIcon.ico from the macOS AppIcon.icns.

    Scripts/make-ico.py

One icon, one source. The .icns is drawn by Scripts/make-icon.swift, and
converting rather than redrawing means the Windows app cannot end up wearing a
slightly different mark than the Mac one.

An .ico is a header, one directory entry per size, and the images themselves —
and since Vista those images may be PNGs, so no bitmap encoder is needed here.
"""

import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Resources" / "AppIcon.icns"
TARGET = ROOT / "Resources" / "AppIcon.ico"

# What Windows actually asks for: the taskbar, alt-tab, and the file itself.
SIZES = [16, 32, 48, 64, 128, 256]


def main():
    if not SOURCE.exists():
        print(f"no {SOURCE.relative_to(ROOT)} — run Scripts/make-icon.sh first", file=sys.stderr)
        return 1
    if not shutil_which("sips"):
        print("sips is macOS only; run this on a Mac", file=sys.stderr)
        return 1

    images = []
    with tempfile.TemporaryDirectory() as tmp:
        for size in SIZES:
            out = Path(tmp) / f"{size}.png"
            result = subprocess.run(
                ["sips", "-s", "format", "png", "-z", str(size), str(size),
                 str(SOURCE), "--out", str(out)],
                capture_output=True)
            if result.returncode != 0 or not out.exists():
                print(f"sips failed at {size}px: {result.stderr.decode().strip()}",
                      file=sys.stderr)
                return 1
            images.append((size, out.read_bytes()))

    # ICONDIR: reserved, type 1 (icon), count.
    blob = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries, payload = b"", b""
    for size, data in images:
        # 256 is written as 0 — the field is one byte and 256 does not fit.
        entries += struct.pack("<BBBBHHII",
                               0 if size == 256 else size,
                               0 if size == 256 else size,
                               0, 0, 1, 32, len(data), offset)
        payload += data
        offset += len(data)

    TARGET.write_bytes(blob + entries + payload)
    print(f"wrote {TARGET.relative_to(ROOT)} "
          f"({TARGET.stat().st_size / 1024:.1f} KB, {len(images)} sizes)")
    return 0


def shutil_which(name):
    from shutil import which
    return which(name)


if __name__ == "__main__":
    sys.exit(main())
