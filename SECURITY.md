# Security

## Reporting a vulnerability

Use [private vulnerability reporting](https://github.com/mahmudulashev/Atlas/security/advisories/new)
rather than opening an issue, so the report stays between us until there is a
fix to ship.

Expect a reply within a week. If a fix is warranted it goes out as a release
with the advisory published alongside it.

## What Atlas actually does

Worth knowing before deciding whether something is a vulnerability:

- It **reads** source files. It never writes to the project it is pointed at.
- It makes **no network requests** of any kind — no telemetry, no update check,
  no crash reporting.
- It writes only to its own folder: `%LOCALAPPDATA%\Atlas` on Windows,
  `~/Library/Application Support/Atlas` on macOS, `~/.local/share/Atlas` on
  Linux. That holds the scan history that powers the Drift section, and the
  interface language.
- The app runs `atlas-engine` as a child process and reads JSON from it.

So the interesting surface is the parser: Atlas reads files it did not write,
including from repositories a user may not trust. A crash, a hang, or
unbounded memory use on a hostile input is worth reporting.

## Supported versions

The latest release. Atlas is small enough that fixes go into the next version
rather than being backported.
