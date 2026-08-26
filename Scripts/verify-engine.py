#!/usr/bin/env python3
"""Check that a build of atlas-engine still behaves.

    Scripts/verify-engine.py .build/release/atlas-engine

Three things are checked, in order of how badly they hurt when broken:

  structure    every index in the report points at something that exists, and
               every card and connector has usable geometry. A UI reads these
               without bounds-checking, so a stale index is a crash there.

  determinism  the same binary over the same files twice, byte for byte.
               Swift reseeds its hashing per process, so anything that reaches
               output through a Dictionary or an unstable sort will differ
               between runs -- which showed up as an unchanged project
               redrawing its Map differently on every scan.

  fixtures     a known project still yields the dependencies it is known to
               have. See Tests/Fixtures/README.md.

  line endings the same project analysed with CRLF endings and with LF
               endings gives the same answer. Swift treats "\r\n" as one
               Character, so a Windows checkout used to read as a single
               enormous line -- every file one line long, every import
               after the first one lost.

Exits non-zero on the first failure, with the reason on stderr.
"""

import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
failures = []


def run(engine, project, *extra):
    """Analyse `project` and return the parsed report."""
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "report.json"
        result = subprocess.run(
            [str(engine), "analyze", str(project), "--out", str(out),
             "--no-drift", *extra],
            capture_output=True, text=True)
        if result.returncode != 0:
            fail(f"engine exited {result.returncode} on {project}\n{result.stderr.strip()}")
            return None
        return json.loads(out.read_text(encoding="utf-8"))


def fail(message):
    failures.append(message)
    print(f"  FAIL  {message}", file=sys.stderr)


def check(condition, message):
    if not condition:
        fail(message)
    return condition


# ---- structure -----------------------------------------------------------

def check_structure(report, label):
    files, symbols = report["files"], report["symbols"]
    nf, ns = len(files), len(symbols)

    check(report["schema"] == 2, f"{label}: schema is {report['schema']}, expected 2")

    for i, s in enumerate(symbols):
        check(-1 <= s["file"] < nf, f"{label}: symbols[{i}].file={s['file']} out of range")
        check(s["difficulty"] in {"easy", "moderate", "hard"},
              f"{label}: symbols[{i}].difficulty={s['difficulty']!r}")

    for i, c in enumerate(report["calls"]):
        check(0 <= c["f"] < ns and 0 <= c["t"] < ns,
              f"{label}: calls[{i}] {c['f']}->{c['t']} out of range")

    for h in report["hubs"]:
        check(0 <= h < ns, f"{label}: hub {h} out of range")

    for i, step in enumerate(report["route"]):
        check(0 <= step["symbol"] < ns, f"{label}: route[{i}].symbol out of range")
        came = step.get("from")
        check(came is None or 0 <= came < ns, f"{label}: route[{i}].from out of range")

    for i, issue in enumerate(report["issues"]):
        check(issue["severity"] in {"low", "medium", "high"},
              f"{label}: issues[{i}].severity={issue['severity']!r}")
        sym = issue.get("symbol")
        check(sym is None or 0 <= sym < ns, f"{label}: issues[{i}].symbol out of range")

    ladder = report.get("map")
    if ladder is None:
        return
    nodes, boxes = ladder["nodes"], ladder["boxes"]
    width, height = ladder["canvas"]["w"], ladder["canvas"]["h"]

    for i, n in enumerate(nodes):
        check(0 <= n["file"] < nf, f"{label}: map.nodes[{i}].file out of range")
        for s_ in n["symbols"]:
            check(0 <= s_ < ns, f"{label}: map.nodes[{i}] symbol {s_} out of range")

    for i, b in enumerate(boxes):
        check(0 <= b["node"] < len(nodes), f"{label}: map.boxes[{i}].node out of range")
        check(b["w"] > 0 and b["h"] > 0, f"{label}: map.boxes[{i}] has no size")
        check(0 <= b["x"] and b["x"] + b["w"] <= width + 1,
              f"{label}: map.boxes[{i}] sticks out of the canvas horizontally")
        check(0 <= b["y"] and b["y"] + b["h"] <= height + 1,
              f"{label}: map.boxes[{i}] sticks out of the canvas vertically")

    placed = {b["node"] for b in boxes}
    check(placed == set(range(len(nodes))),
          f"{label}: {len(nodes) - len(placed)} node(s) in the map were never placed")

    for c, column in enumerate(ladder["columns"]):
        for n_ in column:
            check(0 <= n_ < len(nodes), f"{label}: map.columns[{c}] holds {n_}, out of range")

    for i, e in enumerate(ladder["edges"]):
        check(0 <= e["f"] < len(nodes) and 0 <= e["t"] < len(nodes),
              f"{label}: map.edges[{i}] {e['f']}->{e['t']} out of range")


# ---- determinism ---------------------------------------------------------

def digest(report):
    """A report's identity, ignoring how long it took and when it ran."""
    trimmed = json.loads(json.dumps(report))
    trimmed["project"].pop("parseSeconds", None)
    trimmed["project"].pop("analysedAt", None)
    return hashlib.sha256(json.dumps(trimmed, sort_keys=True).encode()).hexdigest()


def check_determinism(engine, project, label, runs=3):
    seen = set()
    for _ in range(runs):
        report = run(engine, project)
        if report is None:
            return
        seen.add(digest(report))
    check(len(seen) == 1,
          f"{label}: {len(seen)} different results from {runs} identical runs")


# ---- fixtures ------------------------------------------------------------

def check_python_fixture(engine):
    project = ROOT / "Tests" / "Fixtures" / "python-package"
    if not project.is_dir():
        fail("fixture Tests/Fixtures/python-package is missing")
        return
    report = run(engine, project)
    if report is None:
        return
    check_structure(report, "python-package")

    paths = [f["path"] for f in report["files"]]
    edges = {(paths[e["f"]], paths[e["t"]]) for e in report["fileEdges"]}
    for expected in [("pkg/sub/mod.py", "pkg/shared/util.py"),
                     ("pkg/sub/mod.py", "pkg/shared/__init__.py"),
                     ("main.py", "pkg/sub/mod.py")]:
        check(expected in edges,
              f"python-package: lost the dependency {expected[0]} -> {expected[1]}")


def check_line_endings(engine):
    """A Windows checkout and a Unix one must analyse the same.

    Both copies are written deliberately rather than trusting whatever the
    checkout happened to produce: on a Windows runner git has already turned
    these files into CRLF, so converting "in place" would have produced
    \r\r\n and measured nothing useful.
    """
    source = ROOT / "Tests" / "Fixtures" / "python-package"
    if not source.is_dir():
        fail("fixture Tests/Fixtures/python-package is missing")
        return

    def to_lf(data):
        return data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")

    with tempfile.TemporaryDirectory() as tmp:
        unix_copy = Path(tmp) / "lf"
        windows_copy = Path(tmp) / "crlf"
        shutil.copytree(source, unix_copy)
        shutil.copytree(source, windows_copy)
        for path in unix_copy.rglob("*.py"):
            path.write_bytes(to_lf(path.read_bytes()))
        for path in windows_copy.rglob("*.py"):
            path.write_bytes(to_lf(path.read_bytes()).replace(b"\n", b"\r\n"))

        unix = run(engine, unix_copy)
        windows = run(engine, windows_copy)

    if unix is None or windows is None:
        return

    if not check(unix["project"]["lineCount"] == windows["project"]["lineCount"],
                 f"line endings: {unix['project']['lineCount']} lines with LF but "
                 f"{windows['project']['lineCount']} with CRLF"):
        return
    check(digest_without_identity(unix) == digest_without_identity(windows),
          "line endings: CRLF and LF gave different analyses of the same code")


def digest_without_identity(report):
    """A report's identity, ignoring where it ran and what the folder was called."""
    trimmed = json.loads(json.dumps(report))
    for key in ("parseSeconds", "analysedAt", "root", "name"):
        trimmed["project"].pop(key, None)
    return hashlib.sha256(json.dumps(trimmed, sort_keys=True).encode()).hexdigest()


# ---- main ----------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    engine = Path(sys.argv[1]).resolve()
    if not engine.exists():
        print(f"no such binary: {engine}", file=sys.stderr)
        return 2

    print(f"verifying {engine.name}")

    print("  structure   (this repository)")
    report = run(engine, ROOT)
    if report is not None:
        check_structure(report, "self")
        p = report["project"]
        print(f"              {p['fileCount']} files, {p['symbolCount']} symbols, "
              f"{p['callCount']} connections")

    print("  determinism (this repository)")
    check_determinism(engine, ROOT, "self")

    print("  fixtures    (python-package)")
    check_python_fixture(engine)

    print("  line endings(CRLF vs LF)")
    check_line_endings(engine)

    if failures:
        print(f"\n{len(failures)} check(s) failed", file=sys.stderr)
        return 1
    print("\nall checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
