// swift-tools-version: 6.0
import PackageDescription

// Builds `atlas-engine`, the headless half of Atlas.
//
// The macOS app is not built from here — it is a hand-assembled bundle with a
// widget extension, which `Scripts/build.sh` puts together directly with
// `swiftc`. This manifest exists for the other platforms, where there is no
// SwiftUI to build an app against but the analysis engine still runs. Both
// builds compile the same files out of `Sources/AtlasEngine`, so the parser
// and the graph cannot drift apart between platforms.
let package = Package(
    name: "atlas-engine",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "atlas-engine",
            path: "Sources",
            // Only the portable half. `Atlas`, `AtlasWidget` and `Shared`
            // are SwiftUI and stay with the macOS bundle — named here as
            // well as omitted from `sources`, or SwiftPM warns about every
            // file it can see but was not told what to do with.
            exclude: ["Atlas", "AtlasWidget", "Shared"],
            sources: ["AtlasEngine", "AtlasCLI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
