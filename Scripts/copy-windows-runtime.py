#!/usr/bin/env python3
"""Put the Swift runtime beside the engine, so the package runs on a machine
that has never seen Swift.

    Scripts/copy-windows-runtime.py dist/Atlas-windows-x64/atlas-engine.exe

On Windows the Swift runtime is a set of DLLs -- swiftCore.dll, Foundation.dll,
swiftWinSDK.dll and whatever those need -- rather than something the linker
folds into the executable. A machine with the toolchain installed has them on
PATH, so the packaged engine ran on every machine that could build it and on no
machine that had only downloaded it. That is what v1.2 shipped:

    The code execution cannot proceed because swiftWinSDK.dll was not found.

Windows searches the directory of the .exe before it searches PATH, so the fix
is to put them there. This reads the import table of the engine, and of every
DLL it copies, and takes each one that is not part of Windows itself. Then it
resolves the whole closure a second time against nothing but the package
directory and System32 -- all that a downloaded copy of Atlas can count on --
and fails if anything is still missing.

Exits non-zero when a DLL cannot be found, which is the same thing as the
package being broken.
"""

import os
import shutil
import struct
import sys
from pathlib import Path

# A Windows console encodes in the machine's code page -- cp1252 on the CI
# runner -- and Python raises rather than approximating a character it cannot
# encode. That is worth a question mark in a log line, never an exception in
# the middle of packaging: the paths printed below come from wherever the
# toolchain was installed, which on a machine whose user folder is not spelled
# in Latin is not encodable at all. Everything this script writes is otherwise
# ASCII, and the decorated output belongs to package.sh.
for stream in (sys.stdout, sys.stderr):
    if hasattr(stream, "reconfigure"):
        stream.reconfigure(errors="replace")

# API sets: names the loader resolves through a table inside Windows rather
# than by opening a file. They are never on disk, so "not found" is the
# ordinary answer for them and means nothing is wrong.
API_SETS = ("api-ms-win-", "ext-ms-")

# The exception to "if it lives under C:\Windows it is part of Windows". The
# Visual C++ runtime arrives with the redistributable, not with the operating
# system, and a machine that has never installed a C++ program may not have
# it. Microsoft supports shipping these next to an application, so they ride
# along like the Swift ones.
MSVC_RUNTIME = {
    "vcruntime140.dll", "vcruntime140_1.dll", "concrt140.dll",
    "msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll",
    "msvcp140_atomic_wait.dll", "msvcp140_codecvt_ids.dll",
}


def imports(binary):
    """Every DLL named in `binary`'s import tables.

    Just enough of the PE format to answer that. Both the import directory and
    the delay-load directory are arrays of fixed-size records ending at an
    all-zero one, each record holding the address of a name.
    """
    data = binary.read_bytes()
    if data[:2] != b"MZ":
        raise ValueError(f"{binary.name} is not a Windows binary")
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        raise ValueError(f"{binary.name} has no PE header")

    section_count = struct.unpack_from("<H", data, pe + 6)[0]
    optional_size = struct.unpack_from("<H", data, pe + 20)[0]
    optional = pe + 24
    # 0x20b is PE32+, where eight extra bytes of 64-bit fields push the data
    # directories along by sixteen.
    magic = struct.unpack_from("<H", data, optional)[0]
    directories = optional + (112 if magic == 0x20B else 96)

    sections = []
    for i in range(section_count):
        _, virtual_size, address, raw_size, raw = struct.unpack_from(
            "<8sIIII", data, optional + optional_size + i * 40)
        # A section's virtual size can exceed what is stored on disk (.bss and
        # friends) and can also be left at zero by older linkers, in which
        # case the raw size is the one that means anything.
        sections.append((address, max(virtual_size, raw_size), raw))

    def offset(address):
        """Where an address in the loaded image sits in the file."""
        for start, size, raw in sections:
            if start <= address < start + size:
                return raw + (address - start)
        raise ValueError(f"{binary.name}: address {address:#x} is in no section")

    def name_at(address):
        at = offset(address)
        return data[at:data.index(b"\0", at)].decode("ascii")

    found = []
    # Directory 1 is the import table and directory 13 the delay-load table.
    # The records are 20 and 32 bytes, and hold the name at a different word.
    for index, record_size, name_word in ((1, 20, 12), (13, 32, 4)):
        address, size = struct.unpack_from("<II", data, directories + index * 8)
        if not address or not size:
            continue
        at = offset(address)
        while True:
            record = data[at:at + record_size]
            if len(record) < record_size or not any(record):
                break
            at += record_size
            # Delay-load records from before 2005 hold addresses as they would
            # appear in memory rather than as offsets into the image. Reading
            # one as though it were an offset lands somewhere arbitrary, so
            # skip the form instead of guessing at it.
            if index == 13 and not struct.unpack_from("<I", record, 0)[0] & 1:
                continue
            name = struct.unpack_from("<I", record, name_word)[0]
            if name:
                found.append(name_at(name))
    return found


def closure(start, search, windows):
    """Every DLL `start` needs, and what those need in turn.

    Names are resolved against `search` in order, the way the loader does it.
    Windows' own DLLs are recorded but not followed: they need only other
    Windows DLLs, and descending into them would walk the operating system.

    Returns the resolved files by name, and the names nothing could satisfy.
    """
    resolved, missing, seen = {}, [], set()
    queue = [start]
    while queue:
        binary = queue.pop(0)
        for name in imports(binary):
            key = name.lower()
            if key in seen or key.startswith(API_SETS):
                continue
            seen.add(key)
            found = next((d / name for d in search if (d / name).is_file()), None)
            if found is None:
                missing.append((name, binary.name))
                continue
            resolved[name] = found
            # Windows' own DLLs need only other Windows DLLs, so descending
            # into them would walk the operating system. What the package
            # carries out of System32 is not Windows' own, whatever its
            # address: MSVCP140.dll wants VCRUNTIME140_1.dll, and both belong
            # to the Visual C++ redistributable. Carrying a file means
            # carrying what that file needs.
            if windows not in found.parents or key in MSVC_RUNTIME:
                queue.append(found)
    return resolved, missing


def size(byte_count):
    return f"{byte_count / 1_000_000:.1f} MB" if byte_count >= 1_000_000 \
        else f"{byte_count / 1_000:.0f} kB"


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2

    engine = Path(sys.argv[1]).resolve()
    if not engine.is_file():
        print(f"no engine at {engine}", file=sys.stderr)
        return 1

    package = engine.parent
    windows = Path(os.environ.get("SystemRoot", r"C:\Windows"))
    system32 = windows / "System32"
    # The loader's own order: beside the executable, then Windows, then PATH.
    # PATH is where the toolchain's DLLs are, and the only reason any of this
    # has ever worked on a machine that built Atlas.
    search = [package, system32, windows] + [
        Path(entry) for entry in os.environ.get("PATH", "").split(os.pathsep) if entry]

    needed, missing = closure(engine, search, windows)
    if missing:
        for name, wanted_by in missing:
            print(f"{wanted_by} needs {name}, which is on no search path",
                  file=sys.stderr)
        return 1

    copied = []
    for name, found in sorted(needed.items(), key=lambda pair: pair[0].lower()):
        if found.parent == package:
            continue
        if windows in found.parents and name.lower() not in MSVC_RUNTIME:
            continue
        shutil.copy2(found, package / name)
        copied.append((name, found.parent, (package / name).stat().st_size))

    for name, source, bytes_copied in copied:
        print(f"    {name:<34} {size(bytes_copied):>8}   {source}")
    print(f"    {len(copied)} DLL{'' if len(copied) == 1 else 's'}"
          f", {size(sum(count for _, _, count in copied))}")

    # The question a downloaded copy of Atlas asks: with this folder and
    # Windows, and nothing else, does every import resolve? Answered here
    # rather than by starting the engine, because a missing DLL stops the
    # process with a modal dialog that would sit in CI until it timed out.
    shipped, still_missing = closure(engine, [package, system32, windows], windows)
    if still_missing:
        for name, wanted_by in still_missing:
            print(f"::error::{wanted_by} needs {name}, and the package does "
                  f"not carry it", file=sys.stderr)
        return 1

    # Resolving is not enough for the files the package took responsibility
    # for. A Visual C++ runtime DLL answered out of System32 proves only that
    # this machine has the redistributable installed, which is the one thing a
    # downloaded copy of Atlas cannot assume about the machine it lands on.
    borrowed = sorted(name for name, found in shipped.items()
                      if name.lower() in MSVC_RUNTIME and found.parent != package)
    if borrowed:
        for name in borrowed:
            print(f"::error::{name} is being answered by this machine's "
                  f"System32 rather than by the package", file=sys.stderr)
        return 1
    print("    every import resolves against the package and Windows alone")
    return 0


if __name__ == "__main__":
    sys.exit(main())
