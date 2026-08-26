using Avalonia;
using Avalonia.Media;
using Avalonia.Styling;
using System.Collections.Concurrent;

namespace Atlas.Windows.Design;

/// <summary>
/// The visual language of Atlas — "Broadsheet".
///
/// A direct port of Sources/Atlas/UI/Theme.swift, kept deliberately literal:
/// the same hex values, the same names, the same comments about what each ink
/// is allowed to mean. Two of them are load-bearing and never used for
/// anything else:
///
///   <b>cyan</b> — downstream. What this calls.
///   <b>magenta</b> — upstream. What calls this.
///
/// That pairing holds in the map, the inspector and the call chain, which is
/// why direction never needs a legend. If the two files ever disagree, the two
/// builds of Atlas stop being the same product, so changes belong in both.
///
/// Named for the design rather than called <c>Theme</c>, because every
/// Avalonia control inherits a <c>Theme</c> property: inside a control,
/// `Theme.InkCyan` binds to `this.Theme` and no using-alias can outrank it.
/// </summary>
public static class Broadsheet
{
    // MARK: - Colour construction

    private static bool IsDark =>
        Application.Current?.ActualThemeVariant == ThemeVariant.Dark;

    /// <summary>A colour that resolves against the window's current appearance.</summary>
    private static Color Dynamic(uint light, uint dark) => FromHex(IsDark ? dark : light);

    private static Color FromHex(uint hex) => Color.FromRgb(
        (byte)((hex >> 16) & 0xFF), (byte)((hex >> 8) & 0xFF), (byte)(hex & 0xFF));

    // Drawing code asks for these once per frame per element, so the brushes
    // are memoised. The key carries the colour itself, which means a theme
    // switch simply starts hitting different entries rather than needing the
    // cache torn down.
    private static readonly ConcurrentDictionary<uint, IBrush> BrushCache = new();

    /// <summary>A cached brush for a colour, for use inside Render.</summary>
    public static IBrush Brush(Color color)
    {
        uint key = ((uint)color.A << 24) | ((uint)color.R << 16)
                 | ((uint)color.G << 8) | color.B;
        return BrushCache.GetOrAdd(key, _ => new SolidColorBrush(color).ToImmutable());
    }

    /// <summary>The same ink, laid on more lightly.</summary>
    public static Color Fade(Color color, double alpha) =>
        Color.FromArgb((byte)Math.Clamp(alpha * 255, 0, 255), color.R, color.G, color.B);

    // MARK: - Paper and ink
    //
    // Light is the system's real ground: warm off-white stock, near-black ink.
    // Dark is a derived pressing of the same plates — the paper goes to a warm
    // near-black and the ink to the sheet's own white, so the two inks keep
    // their relationship rather than being inverted into something else.

    public static Color Background    => Dynamic(0xF3F2F2, 0x141312);
    public static Color Surface       => Dynamic(0xEAE9E9, 0x1D1B1A);
    public static Color SurfaceRaised => Dynamic(0xF8F4F4, 0x242221);
    public static Color SurfaceSunken => Dynamic(0xE4E2E2, 0x0E0D0C);

    public static Color Border        => Dynamic(0xD7D3D3, 0x35322F);
    public static Color BorderSoft    => Dynamic(0xEAE7E7, 0x272422);
    public static Color BorderStrong  => Dynamic(0xBAB6B6, 0x4A4643);

    /// <summary>The faint rule grid the window is set on.</summary>
    public static Color PaperGrid     => Dynamic(0xE7E4E4, 0x1B1918);

    public static Color TextPrimary   => Dynamic(0x201E1D, 0xF0EDEB);
    public static Color TextSecondary => Dynamic(0x605D5D, 0xA8A29E);
    public static Color TextTertiary  => Dynamic(0x9B9797, 0x7A7570);

    // MARK: - The two process inks
    //
    // Direction is the only thing these ever mean.

    /// <summary>Downstream — what this calls.</summary>
    public static Color InkCyan       => Dynamic(0x0088B0, 0x4FC3E8);
    public static Color InkCyanSoft   => Dynamic(0xE9F8FF, 0x0A303E);
    public static Color InkCyanDeep   => Dynamic(0x006786, 0x99E0FF);

    /// <summary>Upstream — what calls this.</summary>
    public static Color InkMagenta     => Dynamic(0xD6006C, 0xFF7FAE);
    public static Color InkMagentaSoft => Dynamic(0xFFF1F4, 0x4B1528);
    public static Color InkMagentaDeep => Dynamic(0xAA0B56, 0xFFC0D0);

    /// <summary>The third plate. A print treatment, never interface chrome.</summary>
    public static Color InkYellow     => Dynamic(0xEDBB00, 0xE0AB3E);

    // MARK: - Roles
    //
    // Named by job rather than by hue, so a component never reaches for an ink
    // it has no business carrying.

    public static Color Accent        => InkCyan;
    public static Color AccentMuted   => InkCyanSoft;

    /// <summary>
    /// "You are here" is set in ink, not in a hue. Both process inks already
    /// mean a direction, and a third would start competing with them; in print
    /// the answer is weight, so the current step is simply printed solid.
    /// </summary>
    public static Color Marker        => TextPrimary;
    public static Color MarkerMuted   => Dynamic(0xE0DDDD, 0x2A2725);
    public static Color Gold          => Dynamic(0x8A6A2E, 0xC9A45E);
    public static Color Danger        => Dynamic(0xAA0B56, 0xFF7FAE);

    public static Color Edge          => Dynamic(0xBAB6B6, 0x3A3633);
    public static Color EdgeOutgoing  => InkCyan;      // this → other
    public static Color EdgeIncoming  => InkMagenta;   // other → this
    public static Color Connector     => Dynamic(0xBAB6B6, 0x413D3A);

    // MARK: - Graph

    /// <summary>
    /// Declaration kinds. Deliberately quiet: the two directional inks are the
    /// loud pair, and kind must not compete with them.
    /// </summary>
    public static Color ForKind(string kind, bool external = false)
    {
        if (external) return Dynamic(0x9B9797, 0x6B6663);
        return kind switch
        {
            "function"     => Dynamic(0x444141, 0xD4CFCB),
            "method"       => Dynamic(0x605D5D, 0xB4AEAA),
            "initializer"  => Dynamic(0x006786, 0x7FBFD8),
            "type"         => Dynamic(0x8A6A2E, 0xC9A45E),
            "closureOrVar" => Dynamic(0xAA0B56, 0xE79AB6),
            _              => TextPrimary,
        };
    }

    /// <summary>Reading difficulty. One mark of ink, not a coloured box.</summary>
    public static Color ForDifficulty(string difficulty) => difficulty switch
    {
        "easy"     => Dynamic(0x9B9797, 0x7A7570),
        "moderate" => Dynamic(0x8A6A2E, 0xC9A45E),
        "hard"     => Dynamic(0xAA0B56, 0xFF7FAE),
        _          => TextSecondary,
    };

    // MARK: - Code

    public static Color CodePlain      => Dynamic(0x201E1D, 0xE4E0DC);
    public static Color CodeKeyword    => Dynamic(0xAA0B56, 0xE79AB6);
    public static Color CodeString     => Dynamic(0x006786, 0x8FCFE4);
    public static Color CodeNumber     => Dynamic(0x8A6A2E, 0xC9A45E);
    public static Color CodeComment    => Dynamic(0x9B9797, 0x6F6A66);
    public static Color CodeFunction   => Dynamic(0x0088B0, 0x4FC3E8);
    public static Color CodeType       => Dynamic(0x444141, 0xC4BFBB);
    public static Color CodePunct      => Dynamic(0x7D7979, 0x8A8580);
    public static Color CodeGutter     => Dynamic(0xBAB6B6, 0x555049);
    public static Color CodeBackground => Dynamic(0xF8F4F4, 0x181615);
    public static Color CodeHighlight  => Dynamic(0xFFF1F4, 0x2A2321);

    // MARK: - Type
    //
    // One serif throughout, as the system specifies. macOS reaches New York
    // through SwiftUI's `.serif`; Windows has no New York, so the stack falls
    // to Georgia — the closest thing Windows ships in spirit, a warm text
    // serif drawn for screens rather than a scaled print face like Times.
    // Listing New York first means a Mac still gets the face the design was
    // drawn against.

    public static class Fonts
    {
        public static readonly FontFamily Serif =
            new("New York, Georgia, Cambria, Times New Roman, serif");

        public static readonly FontFamily Mono =
            new("SF Mono, Cascadia Mono, Consolas, Menlo, monospace");

        public const double Display = 34;
        public const double Title   = 20;
        public const double Heading = 15;
        public const double Body    = 14;
        public const double Caption = 12.5;
        public const double Micro   = 10.5;

        /// <summary>
        /// Small-caps labels: set in the serif with wide tracking, which is
        /// what makes a section head read as a rule rather than a heading.
        /// </summary>
        public const double Label      = 10;
        public const double LabelTracking = 1.2;

        public const double MonoSize   = 12;
        public const double MonoSmall  = 11;
        public const double Number     = 26;
    }

    // MARK: - Metrics
    //
    // Print radii: 1, 2, 4. Nothing in a printed chart has a soft corner.

    public static class Metric
    {
        public const double Radius         = 2;
        public const double RadiusSmall    = 1;
        public const double RadiusLarge    = 4;
        public const double Gutter         = 20;
        public const double GutterTight    = 10;
        public const double SidebarWidth   = 272;
        public const double InspectorWidth = 324;
        public const double RowHeight      = 26;
    }
}
