import SwiftUI
import AppKit

/// The visual language of Xarita.
///
/// Colours are declared once as light/dark pairs and resolved by AppKit at draw
/// time, so the whole app follows the system appearance without a single
/// `colorScheme` check in a view. The accent pair — turquoise and gold — is
/// borrowed from Samarkand tilework.
enum Theme {

    // MARK: - Colour construction

    /// A colour that resolves per appearance, without an asset catalog.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    // MARK: - Surfaces
    //
    // "Siyoh" — ink. The ground is drafting paper rather than white: a neutral
    // biased toward the accent reads as chosen, where a pure grey reads as
    // inherited. Navy carries structure; vermilion is spent on exactly one
    // thing, the "you are here" marker, so the eye never has to hunt for it.

    static let background      = dynamic(light: 0xEFF1F5, dark: 0x080B12)
    static let surface         = dynamic(light: 0xFFFFFF, dark: 0x101724)
    static let surfaceRaised   = dynamic(light: 0xF6F8FB, dark: 0x151E2E)
    static let surfaceSunken   = dynamic(light: 0xE9ECF3, dark: 0x05070C)

    static let border          = dynamic(light: 0xDBE0EA, dark: 0x1F2A3D)
    static let borderSoft      = dynamic(light: 0xE8ECF3, dark: 0x192234)
    static let borderStrong    = dynamic(light: 0xC3CBDA, dark: 0x2C3A52)

    /// The faint drafting grid drawn behind the whole window.
    static let paperGrid       = dynamic(light: 0xE3E8F1, dark: 0x131B29)

    // MARK: - Text

    static let textPrimary     = dynamic(light: 0x0E1626, dark: 0xE3E9F4)
    static let textSecondary   = dynamic(light: 0x4A566B, dark: 0x98A6BE)
    static let textTertiary    = dynamic(light: 0x7C8698, dark: 0x63718A)

    // MARK: - Accent

    static let accent          = dynamic(light: 0x2B4C87, dark: 0x7FA6E8)
    static let accentMuted     = dynamic(light: 0xDFE7F5, dark: 0x152439)

    /// Reserved for the reader's own position. Nothing else uses it.
    static let marker          = dynamic(light: 0xC0432C, dark: 0xF0705A)
    static let markerMuted     = dynamic(light: 0xF7E3DF, dark: 0x2B1512)

    static let gold            = dynamic(light: 0xA97514, dark: 0xE0AB3E)
    static let danger          = dynamic(light: 0xB1402F, dark: 0xE87A68)

    // MARK: - Graph

    /// Node fill per declaration kind. Distinct hues, matched in perceived
    /// lightness so no one category visually dominates the map.
    static func color(for kind: SymbolKind, external: Bool = false) -> Color {
        if external { return dynamic(light: 0x9AA3B0, dark: 0x525C6B) }
        switch kind {
        case .function:     return dynamic(light: 0x2B4C87, dark: 0x7FA6E8)
        case .method:       return dynamic(light: 0x1F6E7C, dark: 0x5FC2D4)
        case .initializer:  return dynamic(light: 0x5B4A9E, dark: 0x9E90E0)
        case .type:         return dynamic(light: 0xA97514, dark: 0xE0AB3E)
        case .closureOrVar: return dynamic(light: 0xA34668, dark: 0xE58AA8)
        }
    }

    static let edge            = dynamic(light: 0xC3CBDA, dark: 0x24314A)
    static let edgeIncoming    = dynamic(light: 0x8A6A2E, dark: 0xC9A45E)
    static let edgeOutgoing    = dynamic(light: 0x2B4C87, dark: 0x7FA6E8)

    /// Difficulty badges. Green/amber/red reads instantly, and the hues are the
    /// same family as the danger and gold accents so nothing looks bolted on.
    static func color(for difficulty: GraphNode.Difficulty) -> Color {
        switch difficulty {
        case .easy:     return dynamic(light: 0x2F7A54, dark: 0x66C089)
        case .moderate: return dynamic(light: 0xA9750F, dark: 0xE0AB3E)
        case .hard:     return dynamic(light: 0xB1402F, dark: 0xE87A68)
        }
    }

    // MARK: - Code

    /// Syntax colours. Tuned so that in dark mode nothing glows brighter than
    /// the identifiers you are actually trying to read.
    static let codePlain    = dynamic(light: 0x18202F, dark: 0xC9D3E4)
    static let codeKeyword  = dynamic(light: 0x8B3070, dark: 0xDE93C4)
    static let codeString   = dynamic(light: 0x1F6E4A, dark: 0x74C79A)
    static let codeNumber   = dynamic(light: 0xA85A18, dark: 0xE3A467)
    static let codeComment  = dynamic(light: 0x7C8698, dark: 0x5B6A82)
    static let codeFunction = dynamic(light: 0x2B4C87, dark: 0x86ABEB)
    static let codeType     = dynamic(light: 0xA97514, dark: 0xE0AB3E)
    static let codePunct    = dynamic(light: 0x5C6779, dark: 0x8593A9)
    static let codeGutter   = dynamic(light: 0xA9B3C4, dark: 0x44526B)
    static let codeBackground = dynamic(light: 0xFCFDFE, dark: 0x0B1019)
    static let codeHighlight  = dynamic(light: 0xFBF0EC, dark: 0x1A2434)

    // MARK: - Type scale

    enum Font {
        static let display   = SwiftUI.Font.system(size: 30, weight: .semibold, design: .rounded)
        static let title     = SwiftUI.Font.system(size: 19, weight: .semibold)
        static let heading   = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let body      = SwiftUI.Font.system(size: 13, weight: .regular)
        static let caption   = SwiftUI.Font.system(size: 11.5, weight: .regular)
        static let micro     = SwiftUI.Font.system(size: 10, weight: .medium)
        static let mono      = SwiftUI.Font.system(size: 12, design: .monospaced)
        static let monoSmall = SwiftUI.Font.system(size: 11, design: .monospaced)
        /// Tabular figures keep changing counters from jittering.
        static let number    = SwiftUI.Font.system(size: 22, weight: .semibold).monospacedDigit()
    }

    // MARK: - Metrics

    enum Metric {
        static let radius: CGFloat        = 10
        static let radiusSmall: CGFloat   = 6
        static let gutter: CGFloat        = 16
        static let gutterTight: CGFloat   = 10
        static let sidebarWidth: CGFloat  = 268
        static let inspectorWidth: CGFloat = 320
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
