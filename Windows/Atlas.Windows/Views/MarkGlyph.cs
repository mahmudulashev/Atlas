using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;

namespace Atlas.Windows.Views;

/// <summary>
/// Atlas's mark: five nodes and the links between them.
///
/// Drawn rather than shipped as an image so it stays crisp at any size and
/// follows the theme. The one node set in gold is the entry point — the same
/// idea the whole app is about, at the size of a favicon.
/// </summary>
public sealed class MarkGlyph : Control
{
    private static readonly (double X, double Y, double R)[] Nodes =
    [
        (0.50, 0.22, 0.115),
        (0.20, 0.52, 0.082),
        (0.80, 0.50, 0.082),
        (0.38, 0.82, 0.062),
        (0.66, 0.80, 0.062),
    ];

    private static readonly (int A, int B)[] Links =
        [(0, 1), (0, 2), (1, 3), (2, 4), (3, 4), (1, 2)];

    public MarkGlyph(double size)
    {
        Width = size;
        Height = size;
        IsHitTestVisible = false;
    }

    public override void Render(DrawingContext context)
    {
        double s = Math.Min(Bounds.Width, Bounds.Height);
        if (s <= 0) return;
        Point At(int i) => new(Nodes[i].X * s, Nodes[i].Y * s);

        var thread = new Pen(Broadsheet.Brush(Broadsheet.Fade(Broadsheet.Accent, 0.42)),
                             Math.Max(1, s * 0.016));
        foreach (var (a, b) in Links) context.DrawLine(thread, At(a), At(b));

        for (int i = 0; i < Nodes.Length; i++)
        {
            double r = Nodes[i].R * s;
            context.DrawEllipse(
                Broadsheet.Brush(i == 0 ? Broadsheet.Gold : Broadsheet.Accent),
                null, At(i), r, r);
        }
    }
}
