**Read a codebase you have never seen.** What it is, what calls what, and where to start.

### Download

| Platform | | |
|---|---|---|
| **macOS** | Apple Silicon · 14+ | [`Atlas-VERSION.dmg`](https://github.com/mahmudulashev/Atlas/releases/download/vVERSION/Atlas-VERSION.dmg) |
| **Windows** | x64 · 10+ | [`Atlas-VERSION-windows-x64.zip`](https://github.com/mahmudulashev/Atlas/releases/download/vVERSION/Atlas-VERSION-windows-x64.zip) |
| **Linux** | x64 | [`Atlas-VERSION-linux-x64.tar.gz`](https://github.com/mahmudulashev/Atlas/releases/download/vVERSION/Atlas-VERSION-linux-x64.tar.gz) |

### Installing

**macOS** — open the disk image and drag Atlas to Applications. If Gatekeeper stops the first launch, right-click the app and choose Open, or run `xattr -cr /Applications/Atlas.app`.

**Windows** — unzip anywhere and run `Atlas.exe`.

**Linux** — `tar xzf Atlas-VERSION-linux-x64.tar.gz`, then run `./Atlas`.

On Windows and Linux, keep `atlas-engine` in the same folder as the app. That is the analysis; the app runs it as a separate program.

No installer, no runtime to download, and nothing written outside your own user folder — Atlas keeps its scan history there so it can tell you what moved since last time.

### One engine, three platforms

The reading is done by the same Swift code everywhere. Only the drawing is written twice, because SwiftUI does not exist off Apple platforms and there is no honest way around that.

You can check the claim yourself:

```
atlas-engine analyze <folder> --pretty
```

That prints everything the app draws. CI runs it on all three platforms on every push and compares the results; a difference fails the build.

### Verifying a download

```
shasum -a 256 -c Atlas-VERSION.dmg.sha256
```

MIT licensed.
