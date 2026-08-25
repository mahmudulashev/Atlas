import SwiftUI
import AppKit

/// The visual language of Atlas — "Broadsheet".
///
/// The app is set as a printed chart rather than a dark developer tool: ink on
/// paper, one serif, and the process inks carrying meaning rather than
/// decoration. Two of them are load-bearing and never used for anything else:
///
///   **cyan** — downstream. What this calls.
///   **magenta** — upstream. What calls this.
///
/// That pairing holds in the map, the inspector and the call chain, which is
/// why direction never needs a legend.
enum Theme {

    // MARK: - Colour construction

    /// A colour that resolves per appearance, without an asset catalog.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    // MARK: - Paper and ink
    //
    // Light is the system's real ground: warm off-white stock, near-black ink.
    // Dark is a derived pressing of the same plates — the paper goes to a warm
    // near-black and the ink to the sheet's own white, so the two inks keep
    // their relationship rather than being inverted into something else.

    static let background      = dynamic(light: 0xF3F2F2, dark: 0x141312)
    static let surface         = dynamic(light: 0xEAE9E9, dark: 0x1D1B1A)
    static let surfaceRaised   = dynamic(light: 0xF8F4F4, dark: 0x242221)
    static let surfaceSunken   = dynamic(light: 0xE4E2E2, dark: 0x0E0D0C)

    static let border          = dynamic(light: 0xD7D3D3, dark: 0x35322F)
    static let borderSoft      = dynamic(light: 0xEAE7E7, dark: 0x272422)
    static let borderStrong    = dynamic(light: 0xBAB6B6, dark: 0x4A4643)

    /// The faint rule grid the window is set on.
    static let paperGrid       = dynamic(light: 0xE7E4E4, dark: 0x1B1918)

    static let textPrimary     = dynamic(light: 0x201E1D, dark: 0xF0EDEB)
    static let textSecondary   = dynamic(light: 0x605D5D, dark: 0xA8A29E)
    static let textTertiary    = dynamic(light: 0x9B9797, dark: 0x7A7570)

    // MARK: - The two process inks
    //
    // Direction is the only thing these ever mean.

    /// Downstream — what this calls.
    static let inkCyan         = dynamic(light: 0x0088B0, dark: 0x4FC3E8)
    static let inkCyanSoft     = dynamic(light: 0xE9F8FF, dark: 0x0A303E)
    static let inkCyanDeep     = dynamic(light: 0x006786, dark: 0x99E0FF)

    /// Upstream — what calls this.
    static let inkMagenta      = dynamic(light: 0xD6006C, dark: 0xFF7FAE)
    static let inkMagentaSoft  = dynamic(light: 0xFFF1F4, dark: 0x4B1528)
    static let inkMagentaDeep  = dynamic(light: 0xAA0B56, dark: 0xFFC0D0)

    /// The third plate. A print treatment, never interface chrome.
    static let inkYellow       = dynamic(light: 0xEDBB00, dark: 0xE0AB3E)

    // MARK: - Roles
    //
    // Named by job rather than by hue, so a component never reaches for an ink
    // it has no business carrying.

    static let accent          = inkCyan
    static let accentMuted     = inkCyanSoft

    /// "You are here" is set in ink, not in a hue.
    ///
    /// The obvious move is to give the reader's position its own colour, but
    /// both process inks already mean a direction and a third hue would start
    /// competing with them. In print the answer is weight: the current step is
    /// simply the one printed solid, and the design does the same.
    static let marker          = textPrimary
    static let markerMuted     = dynamic(light: 0xE0DDDD, dark: 0x2A2725)
    static let gold            = dynamic(light: 0x8A6A2E, dark: 0xC9A45E)
    static let danger          = dynamic(light: 0xAA0B56, dark: 0xFF7FAE)

    static let edge            = dynamic(light: 0xBAB6B6, dark: 0x3A3633)
    static let edgeOutgoing    = inkCyan             // this → other
    static let edgeIncoming    = inkMagenta          // other → this

    // MARK: - Graph

    /// Declaration kinds. Deliberately quiet: the two directional inks are the
    /// loud pair, and kind must not compete with them.
    static func color(for kind: SymbolKind, external: Bool = false) -> Color {
        if external { return dynamic(light: 0x9B9797, dark: 0x6B6663) }
        switch kind {
        case .function:     return dynamic(light: 0x444141, dark: 0xD4CFCB)
        case .method:       return dynamic(light: 0x605D5D, dark: 0xB4AEAA)
        case .initializer:  return dynamic(light: 0x006786, dark: 0x7FBFD8)
        case .type:         return dynamic(light: 0x8A6A2E, dark: 0xC9A45E)
        case .closureOrVar: return dynamic(light: 0xAA0B56, dark: 0xE79AB6)
        }
    }

    /// Reading difficulty. One mark of ink, not a coloured box.
    static func color(for difficulty: GraphNode.Difficulty) -> Color {
        switch difficulty {
        case .easy:     return dynamic(light: 0x9B9797, dark: 0x7A7570)
        case .moderate: return dynamic(light: 0x8A6A2E, dark: 0xC9A45E)
        case .hard:     return dynamic(light: 0xAA0B56, dark: 0xFF7FAE)
        }
    }

    // MARK: - Code

    static let codePlain    = dynamic(light: 0x201E1D, dark: 0xE4E0DC)
    static let codeKeyword  = dynamic(light: 0xAA0B56, dark: 0xE79AB6)
    static let codeString   = dynamic(light: 0x006786, dark: 0x8FCFE4)
    static let codeNumber   = dynamic(light: 0x8A6A2E, dark: 0xC9A45E)
    static let codeComment  = dynamic(light: 0x9B9797, dark: 0x6F6A66)
    static let codeFunction = dynamic(light: 0x0088B0, dark: 0x4FC3E8)
    static let codeType     = dynamic(light: 0x444141, dark: 0xC4BFBB)
    static let codePunct    = dynamic(light: 0x7D7979, dark: 0x8A8580)
    static let codeGutter   = dynamic(light: 0xBAB6B6, dark: 0x555049)
    static let codeBackground = dynamic(light: 0xF8F4F4, dark: 0x181615)
    static let codeHighlight  = dynamic(light: 0xFFF1F4, dark: 0x2A2321)

    static let connector       = dynamic(light: 0xBAB6B6, dark: 0x413D3A)

    // MARK: - Type
    //
    // One serif throughout, as the system specifies. New York ships with macOS
    // and is reached through `.serif`, so nothing has to be bundled and the
    // text renders with the system's own optical sizing.

    enum Font {
        static let display   = SwiftUI.Font.system(size: 34, weight: .semibold, design: .serif)
        static let title     = SwiftUI.Font.system(size: 20, weight: .semibold, design: .serif)
        static let heading   = SwiftUI.Font.system(size: 15, weight: .semibold, design: .serif)
        static let body      = SwiftUI.Font.system(size: 14, design: .serif)
        static let caption   = SwiftUI.Font.system(size: 12.5, design: .serif)
        static let micro     = SwiftUI.Font.system(size: 10.5, weight: .medium, design: .serif)

        /// Small caps labels: the system sets these in the serif with wide
        /// tracking, which is what makes a section head read as a rule rather
        /// than a heading.
        static let label     = SwiftUI.Font.system(size: 10, weight: .semibold, design: .serif)

        static let mono      = SwiftUI.Font.system(size: 12, design: .monospaced)
        static let monoSmall = SwiftUI.Font.system(size: 11, design: .monospaced)
        static let number    = SwiftUI.Font.system(size: 26, weight: .semibold, design: .serif)
                                       .monospacedDigit()
    }

    // MARK: - Metrics
    //
    // Print radii: 1, 2, 4. Nothing in a printed chart has a soft corner.

    enum Metric {
        static let radius: CGFloat        = 2
        static let radiusSmall: CGFloat   = 1
        static let radiusLarge: CGFloat   = 4
        static let gutter: CGFloat        = 20
        static let gutterTight: CGFloat   = 10
        static let sidebarWidth: CGFloat  = 272
        static let inspectorWidth: CGFloat = 324
        static let rowHeight: CGFloat     = 26
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green:   CGFloat((hex >> 8) & 0xFF) / 255,
                  blue:    CGFloat(hex & 0xFF) / 255,
                  alpha:   1)
    }
}
