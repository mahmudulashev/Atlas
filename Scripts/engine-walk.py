#!/usr/bin/env python3
"""Show what the engine actually walked.

    Scripts/engine-walk.py <engine> <project>

Prints the file count, a handful of paths and a tally by extension. For
working out why one machine sees a project differently from another, where the
count alone says something is wrong but not what.
"""

import json
import subprocess
import sys


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2

    engine, project = sys.argv[1], sys.argv[2]
    result = subprocess.run(
        [engine, "analyze", project, "--no-drift", "--no-layout"],
        capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        print(f"  exit {result.returncode}: {result.stderr.strip()}")
        return 0

    report = json.loads(result.stdout)
    paths = [f["path"] for f in report["files"]]
    print(f"  {report['project']['fileCount']} files, root={report['project']['root']}")
    for path in paths[:6]:
        print(f"      {path}")

    tally = {}
    for path in paths:
        tally[path.rsplit(".", 1)[-1]] = tally.get(path.rsplit(".", 1)[-1], 0) + 1
    ranked = sorted(tally.items(), key=lambda kv: -kv[1])
    print(f"      by extension: {dict(ranked)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
