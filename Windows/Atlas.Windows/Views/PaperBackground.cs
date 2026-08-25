using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;

namespace Atlas.Windows.Views;

/// <summary>
/// The drafting grid the whole window sits on.
///
/// A flat fill reads as an empty container; a ruled ground reads as a working
/// surface, which is the difference between the app feeling like a dialog and
/// feeling like something you work on. Drawn rather than tiled from an image
/// so it stays crisp at any scale factor and follows the theme.
///
/// Ported from Sources/Atlas/UI/PaperBackground.swift. SwiftUI's
/// <c>Canvas { context, size in … }</c> and Avalonia's
/// <c>Render(DrawingContext)</c> are the same idea — immediate mode over a
/// retained-mode toolkit — which is why the body below is line for line the
/// same drawing.
/// </summary>
public sealed class PaperBackground : Control
{
    public static readonly StyledProperty<double> SpacingProperty =
        AvaloniaProperty.Register<PaperBackground, double>(nameof(Spacing), 26);

    public double Spacing
    {
        get => GetValue(SpacingProperty);
        set => SetValue(SpacingProperty, value);
    }

    static PaperBackground()
    {
        AffectsRender<PaperBackground>(SpacingProperty);
        // Nothing here is interactive; the grid must never eat a click meant
        // for what is drawn on top of it.
        IsHitTestVisibleProperty.OverrideDefaultValue<PaperBackground>(false);
    }

    public override void Render(DrawingContext context)
    {
        var size = Bounds.Size;
        if (size.Width <= 0 || size.Height <= 0) return;

        context.FillRectangle(Broadsheet.Brush(Broadsheet.Background),
                              new Rect(0, 0, size.Width, size.Height));

        var pen = new Pen(Broadsheet.Brush(Broadsheet.PaperGrid), 1);
        for (double x = 0; x <= size.Width; x += Spacing)
            context.DrawLine(pen, new Point(x, 0), new Point(x, size.Height));
        for (double y = 0; y <= size.Height; y += Spacing)
            context.DrawLine(pen, new Point(0, y), new Point(size.Width, y));
    }
}
