using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

/// <summary>
/// One declaration's immediate neighbourhood: who calls it, what it calls.
///
/// Never more than eleven things — five callers, the subject, five callees —
/// in fixed columns, so the eye always knows where to look. The whole-codebase
/// graph this replaced produced a hairball: technically correct, visually
/// impressive, and unreadable, because nobody can follow sixteen hundred nodes.
///
/// Ported from Sources/Atlas/UI/CallTreeView.swift.
/// </summary>
public sealed class CallTreeView : Control
{
    private const double RowHeight = 30;
    private const double ColumnWidth = 176;
    private const int MaxPerSide = 5;

    private readonly Report _report;
    private readonly Strings _t;
    private readonly SymbolEntry? _subject;
    private readonly List<int> _callers = [];
    private readonly List<int> _callees = [];
    private readonly int _hiddenCallers;
    private readonly int _hiddenCallees;
    private readonly int _rows;

    public CallTreeView(Report report, Strings t, int index)
    {
        _report = report;
        _t = t;

        if (index >= 0 && index < report.Symbols.Count)
        {
            _subject = report.Symbols[index];
            var allCallers = report.Calls.Where(c => c.To == index)
                                   .Select(c => c.From).Distinct().ToList();
            var allCallees = report.Calls.Where(c => c.From == index)
                                   .Select(c => c.To).Distinct().ToList();
            _callers = allCallers.Take(MaxPerSide).ToList();
            _callees = allCallees.Take(MaxPerSide).ToList();
            _hiddenCallers = allCallers.Count - _callers.Count;
            _hiddenCallees = allCallees.Count - _callees.Count;
        }
        _rows = Math.Max(1, Math.Max(_callers.Count, _callees.Count));
    }

    protected override Size MeasureOverride(Size availableSize) =>
        new(availableSize.Width, _rows * RowHeight + 44);

    /// <summary>
    /// Vertical centre of row <paramref name="index"/> in a column of
    /// <paramref name="count"/>, centred against the tallest column.
    /// </summary>
    private double Y(int index, int count) =>
        17 + (_rows * RowHeight - count * RowHeight) / 2 + index * RowHeight + RowHeight / 2;

    public override void Render(DrawingContext context)
    {
        if (_subject is null) return;
        var size = Bounds.Size;
        if (size.Width <= 0) return;

        context.FillRectangle(Broadsheet.Brush(Broadsheet.Surface),
                              new Rect(0, 0, size.Width, size.Height));

        double midX = size.Width / 2;
        double leftEdge = midX - ColumnWidth / 2 - 8;
        double rightEdge = midX + ColumnWidth / 2 + 8;
        double centreY = _rows * RowHeight / 2 + 17;
        double sourceX = midX - ColumnWidth / 2;
        double targetX = midX + ColumnWidth / 2;

        // Incoming in magenta, outgoing in cyan. The same pairing as the Map
        // and the inspector, doing the same job: pointing a direction.
        for (int i = 0; i < _callers.Count; i++)
        {
            Curve(context, new Point(leftEdge, Y(i, _callers.Count)),
                  new Point(sourceX, centreY), 34,
                  Broadsheet.Fade(Broadsheet.EdgeIncoming, 0.55));
        }
        for (int i = 0; i < _callees.Count; i++)
        {
            Curve(context, new Point(targetX, centreY),
                  new Point(rightEdge, Y(i, _callees.Count)), 34,
                  Broadsheet.Fade(Broadsheet.EdgeOutgoing, 0.55));
        }

        // The side columns start clear of the centre chip, which is
        // ColumnWidth wide and centred on midX — not clear of midX itself, or
        // the names print over the subject.
        Column(context, _callers, _hiddenCallers, leftEdge - 16 - ColumnWidth,
               _t["callers"], Broadsheet.EdgeIncoming, _t["noCallers"], rightAligned: true);
        Column(context, _callees, _hiddenCallees, rightEdge + 16,
               _t["callees"], Broadsheet.EdgeOutgoing, _t["noCallees"], rightAligned: false);
        Centre(context, midX, centreY);
    }

    private static void Curve(DrawingContext context, Point from, Point to,
                              double bend, Color ink)
    {
        var geometry = new StreamGeometry();
        using (var pen = geometry.Open())
        {
            pen.BeginFigure(from, false);
            pen.CubicBezierTo(new Point(from.X + bend, from.Y),
                              new Point(to.X - bend, to.Y), to);
            pen.EndFigure(false);
        }
        context.DrawGeometry(null, new Pen(Broadsheet.Brush(ink), 1.3), geometry);
    }

    private void Column(DrawingContext context, List<int> ids, int hidden, double x,
                        string title, Color tint, string empty, bool rightAligned)
    {
        var heading = Text(title.ToUpperInvariant(), Broadsheet.Fonts.Serif,
                           Broadsheet.Fonts.Micro, Broadsheet.Fade(tint, 0.9));
        context.DrawText(heading,
            new Point(rightAligned ? x + ColumnWidth - heading.Width : x, 0));

        if (ids.Count == 0)
        {
            var none = Text(empty, Broadsheet.Fonts.Serif,
                            Broadsheet.Fonts.Micro, Broadsheet.TextTertiary);
            context.DrawText(none, new Point(
                rightAligned ? x + ColumnWidth - none.Width : x,
                17 + _rows * RowHeight / 2 - none.Height / 2));
            return;
        }

        for (int i = 0; i < ids.Count; i++)
        {
            var symbol = _report.Symbols[ids[i]];
            var name = Text(symbol.Display, Broadsheet.Fonts.Mono,
                            Broadsheet.Fonts.MonoSmall, Broadsheet.TextSecondary);
            name.MaxTextWidth = ColumnWidth;
            name.MaxLineCount = 1;
            name.Trimming = TextTrimming.CharacterEllipsis;
            context.DrawText(name, new Point(
                rightAligned ? x + ColumnWidth - name.Width : x,
                Y(i, ids.Count) - name.Height / 2));
        }

        if (hidden > 0)
        {
            var more = Text($"+{hidden.ToString(CultureInfo.InvariantCulture)}",
                            Broadsheet.Fonts.Serif, Broadsheet.Fonts.Micro,
                            Broadsheet.TextTertiary);
            context.DrawText(more, new Point(
                rightAligned ? x + ColumnWidth - more.Width : x,
                Y(ids.Count - 1, ids.Count) + RowHeight / 2));
        }
    }

    private void Centre(DrawingContext context, double midX, double centreY)
    {
        var name = Text(_subject!.Name, Broadsheet.Fonts.Mono, Broadsheet.Fonts.MonoSize,
                        Broadsheet.TextPrimary, FontWeight.SemiBold);
        name.MaxTextWidth = ColumnWidth;
        name.MaxLineCount = 1;
        name.Trimming = TextTrimming.CharacterEllipsis;

        double top = centreY - name.Height / 2 - (_subject.Container is null ? 0 : 8);
        var box = new Rect(midX - ColumnWidth / 2, top - 8, ColumnWidth,
                           name.Height + 16 + (_subject.Container is null ? 0 : 14));
        context.FillRectangle(Broadsheet.Brush(Broadsheet.SurfaceRaised), box);
        context.DrawRectangle(null, new Pen(Broadsheet.Brush(Broadsheet.Border), 1), box);

        context.DrawText(name, new Point(midX - name.Width / 2, top));

        if (_subject.Container is { Length: > 0 } container)
        {
            var owner = Text(container, Broadsheet.Fonts.Serif, Broadsheet.Fonts.Micro,
                             Broadsheet.TextTertiary);
            context.DrawText(owner, new Point(midX - owner.Width / 2, top + name.Height + 2));
        }
    }

    private static FormattedText Text(string value, FontFamily family, double size,
                                      Color ink, FontWeight weight = FontWeight.Normal) =>
        new(value, CultureInfo.CurrentCulture, FlowDirection.LeftToRight,
            new Typeface(family, FontStyle.Normal, weight), size, Broadsheet.Brush(ink));
}
