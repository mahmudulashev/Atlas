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

    static let background      = dynamic(light: 0xF6F7F9, dark: 0x0A0C10)
    static let surface         = dynamic(light: 0xFFFFFF, dark: 0x12151C)
    static let surfaceRaised   = dynamic(light: 0xFFFFFF, dark: 0x191D26)
    static let surfaceSunken   = dynamic(light: 0xEDEFF3, dark: 0x070910)

    static let border          = dynamic(light: 0xE3E7EE, dark: 0x232935)
    static let borderStrong    = dynamic(light: 0xC8CFDA, dark: 0x333B4A)

    // MARK: - Text

    static let textPrimary     = dynamic(light: 0x10131A, dark: 0xE8EDF5)
    static let textSecondary   = dynamic(light: 0x54606F, dark: 0x98A3B5)
    static let textTertiary    = dynamic(light: 0x8992A0, dark: 0x626D7E)

    // MARK: - Accent

    static let accent          = dynamic(light: 0x0E8F86, dark: 0x3FC7BE)
    static let accentMuted     = dynamic(light: 0xD8F0EE, dark: 0x14322F)
    static let gold            = dynamic(light: 0xA9750F, dark: 0xE0A53A)
    static let danger          = dynamic(light: 0xC23A47, dark: 0xF4707E)

    // MARK: - Graph

    /// Node fill per declaration kind. Distinct hues, matched in perceived
    /// lightness so no one category visually dominates the map.
    static func color(for kind: SymbolKind, external: Bool = false) -> Color {
        if external { return dynamic(light: 0x9AA3B0, dark: 0x525C6B) }
        switch kind {
        case .function:     return dynamic(light: 0x2C6FD4, dark: 0x5A9CFF)
        case .method:       return dynamic(light: 0x0E8F86, dark: 0x3FC7BE)
        case .initializer:  return dynamic(light: 0x6B4BC8, dark: 0xA98BFF)
        case .type:         return dynamic(light: 0xA9750F, dark: 0xE0A53A)
        case .closureOrVar: return dynamic(light: 0xC0507A, dark: 0xF08CB0)
        }
    }

    static let edge            = dynamic(light: 0xB9C1CD, dark: 0x2C3441)
    static let edgeHighlight   = dynamic(light: 0x0E8F86, dark: 0x3FC7BE)
    static let edgeIncoming    = dynamic(light: 0xC23A47, dark: 0xF4707E)
    static let edgeOutgoing    = dynamic(light: 0x2C6FD4, dark: 0x5A9CFF)
    static let canvasGrid      = dynamic(light: 0xE8EBF0, dark: 0x141821)

    /// Difficulty badges. Green/amber/red reads instantly, and the hues are the
    /// same family as the danger and gold accents so nothing looks bolted on.
    static func color(for difficulty: GraphNode.Difficulty) -> Color {
        switch difficulty {
        case .easy:     return dynamic(light: 0x1B7F4B, dark: 0x5BC98A)
        case .moderate: return dynamic(light: 0xA9750F, dark: 0xE0A53A)
        case .hard:     return dynamic(light: 0xC23A47, dark: 0xF4707E)
        }
    }

    // MARK: - Code

    /// Syntax colours. Tuned so that in dark mode nothing glows brighter than
    /// the identifiers you are actually trying to read.
    static let codePlain    = dynamic(light: 0x24292F, dark: 0xCBD3E1)
    static let codeKeyword  = dynamic(light: 0xA02585, dark: 0xE58FD0)
    static let codeString   = dynamic(light: 0x0A7B2E, dark: 0x7FD98F)
    static let codeNumber   = dynamic(light: 0xB35309, dark: 0xF0A45C)
    static let codeComment  = dynamic(light: 0x6A737D, dark: 0x5F6B7C)
    static let codeFunction = dynamic(light: 0x2C6FD4, dark: 0x74B0FF)
    static let codeType     = dynamic(light: 0xA9750F, dark: 0xE0A53A)
    static let codePunct    = dynamic(light: 0x57606A, dark: 0x8B95A5)
    static let codeGutter   = dynamic(light: 0xAFB8C3, dark: 0x4A5464)
    static let codeBackground = dynamic(light: 0xFBFCFD, dark: 0x0D1017)
    static let codeHighlight  = dynamic(light: 0xFFF7D6, dark: 0x1C2233)

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
