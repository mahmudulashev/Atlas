using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

/// <summary>
/// The call ladder: what runs first, and what it leans on.
///
/// Columns are dependency depth — nothing calls the first column, and nothing
/// in the last calls anything — so every link runs left to right and a line
/// going backwards is a cycle, impossible to miss.
///
/// Ported from Sources/Atlas/UI/LadderView.swift. The placement is not ported:
/// it comes from the engine's LadderLayout, the same code the macOS build
/// draws, so the two apps put the same file in the same box. What is here is
/// only the drawing and the pointer handling.
/// </summary>
public sealed class LadderView : Control
{
    private readonly Report _report;
    private readonly Strings _t;
    private readonly MapInfo _map;

    // Adjacency, built once, so a selection can be highlighted without
    // walking every edge each frame.
    private readonly List<int>[] _outgoing;
    private readonly List<int>[] _incoming;
    private readonly Dictionary<int, Box> _boxOf;

    private int? _selected;
    private HashSet<int> _downstream = [];
    private HashSet<int> _upstream = [];
    private HashSet<int> _lit = [];

    private double _scale = 1;
    private Point _offset;
    private Point _dragFrom;
    private Point _dragAnchor;
    private bool _dragging;
    private bool _fitted;

    public LadderView(Report report, Strings t)
    {
        _report = report;
        _t = t;
        _map = report.Map ?? new MapInfo();

        _outgoing = BuildAdjacency(e => e.From, e => e.To);
        _incoming = BuildAdjacency(e => e.To, e => e.From);
        _boxOf = _map.Boxes.ToDictionary(b => b.Node);

        ClipToBounds = true;
        Focusable = true;
        if (Screenshot.Select is { } node) Choose(node);
    }

    private List<int>[] BuildAdjacency(Func<MapEdge, int> key, Func<MapEdge, int> value)
    {
        var lists = new List<int>[_map.Nodes.Count];
        for (int i = 0; i < lists.Length; i++) lists[i] = [];
        foreach (var edge in _map.Edges)
        {
            int k = key(edge), v = value(edge);
            if (k >= 0 && k < lists.Length && v >= 0 && v < lists.Length) lists[k].Add(v);
        }
        return lists;
    }

    // MARK: - Selection

    /// <summary>Everything reachable from a file, in one direction.</summary>
    private HashSet<int> Reach(int index, bool downstream)
    {
        var seen = new HashSet<int>();
        if (index < 0 || index >= _map.Nodes.Count) return seen;

        var frontier = new List<int> { index };
        while (frontier.Count > 0)
        {
            var next = new List<int>();
            foreach (var node in frontier)
            {
                foreach (var neighbour in downstream ? _outgoing[node] : _incoming[node])
                {
                    if (seen.Add(neighbour)) next.Add(neighbour);
                }
            }
            frontier = next;
        }
        return seen;
    }

    private void Choose(int? node)
    {
        _selected = node;
        if (node is { } picked)
        {
            _downstream = Reach(picked, downstream: true);
            _upstream = Reach(picked, downstream: false);
            _lit = [.. _downstream, .. _upstream, picked];
        }
        else
        {
            _downstream = _upstream = _lit = [];
        }
        InvalidateVisual();
    }

    private int? BoxAt(Point point)
    {
        foreach (var box in _map.Boxes)
        {
            var rect = Place(box);
            if (rect.Contains(point)) return box.Node;
        }
        return null;
    }

    // MARK: - Pan, zoom, fit

    private Rect Place(Box box) => new(
        box.X * _scale + _offset.X, box.Y * _scale + _offset.Y,
        box.Width * _scale, box.Height * _scale);

    private static double Clamp(double scale) => Math.Clamp(scale, 0.25, 3.0);

    private void Fit()
    {
        var size = Bounds.Size;
        double w = _map.Canvas.Width, h = _map.Canvas.Height;
        if (size.Width <= 0 || size.Height <= 0 || w <= 0 || h <= 0) return;

        // A little margin, and never blown up past life size — a six-file
        // project magnified to fill the window looks broken, not close up.
        _scale = Clamp(Math.Min(Math.Min((size.Width - 48) / w, (size.Height - 96) / h), 1));
        _offset = new Point((size.Width - w * _scale) / 2, (size.Height - h * _scale) / 2);
        _fitted = true;
        InvalidateVisual();
    }

    protected override void OnPointerPressed(PointerPressedEventArgs e)
    {
        base.OnPointerPressed(e);
        _dragFrom = e.GetPosition(this);
        _dragAnchor = _offset;
        _dragging = true;
        e.Pointer.Capture(this);
    }

    protected override void OnPointerMoved(PointerEventArgs e)
    {
        base.OnPointerMoved(e);
        if (!_dragging) return;
        var now = e.GetPosition(this);
        _offset = new Point(_dragAnchor.X + (now.X - _dragFrom.X),
                            _dragAnchor.Y + (now.Y - _dragFrom.Y));
        InvalidateVisual();
    }

    protected override void OnPointerReleased(PointerReleasedEventArgs e)
    {
        base.OnPointerReleased(e);
        var now = e.GetPosition(this);
        bool moved = Math.Abs(now.X - _dragFrom.X) > 3 || Math.Abs(now.Y - _dragFrom.Y) > 3;
        _dragging = false;
        e.Pointer.Capture(null);

        // A drag that ends where it started is a click; anything else was a pan.
        if (!moved) Choose(BoxAt(now) is { } hit && hit != _selected ? hit : null);
    }

    protected override void OnPointerWheelChanged(PointerWheelEventArgs e)
    {
        base.OnPointerWheelChanged(e);
        var at = e.GetPosition(this);
        double factor = Clamp(_scale * (1 + e.Delta.Y * 0.12)) / _scale;
        if (Math.Abs(factor - 1) < 0.0001) return;

        // Zoom about the pointer, not the origin, or the thing being looked at
        // slides out from under it.
        _offset = new Point(at.X - (at.X - _offset.X) * factor,
                            at.Y - (at.Y - _offset.Y) * factor);
        _scale = Clamp(_scale * factor);
        InvalidateVisual();
    }

    protected override void OnSizeChanged(SizeChangedEventArgs e)
    {
        base.OnSizeChanged(e);
        if (!_fitted) Fit();
    }

    // MARK: - Drawing

    public override void Render(DrawingContext context)
    {
        var size = Bounds.Size;
        if (size.Width <= 0 || size.Height <= 0 || _map.Boxes.Count == 0) return;
        if (!_fitted) Fit();

        DrawColumnHeads(context);
        DrawLinks(context);
        DrawBoxes(context, size);
    }

    private void DrawColumnHeads(DrawingContext context)
    {
        for (int c = 0; c < _map.Columns.Count; c++)
        {
            var column = _map.Columns[c];
            if (column.Count == 0) continue;

            string label = c == 0 ? _t["columnEntry"]
                         : c == _map.Columns.Count - 1 ? _t["columnFoundation"]
                         : _t.Format("columnDepth", c);

            var text = Text($"{label} · {column.Count}",
                            Broadsheet.Fonts.Serif, 9.5 * Math.Max(_scale, 0.75),
                            Broadsheet.TextTertiary, FontWeight.SemiBold);
            context.DrawText(text, new Point(c * 156 * _scale + _offset.X, 8 * _scale + _offset.Y));
        }
    }

    private void DrawLinks(DrawingContext context)
    {
        // Quietest first, so highlights land on top of the greyed-out mass
        // rather than under it.
        var links = new List<(Geometry Path, Color Ink, double Width, double Opacity)>();

        foreach (var edge in _map.Edges)
        {
            if (!TryBox(edge.From, out var from) || !TryBox(edge.To, out var to)) continue;

            var start = new Point(from.Right, from.Center.Y);
            var end = new Point(to.Left, to.Center.Y);
            double bend = Math.Max(26 * _scale, (end.X - start.X) * 0.55);

            var geometry = new StreamGeometry();
            using (var pen = geometry.Open())
            {
                pen.BeginFigure(start, false);
                pen.CubicBezierTo(new Point(start.X + bend, start.Y),
                                  new Point(end.X - bend, end.Y), end);
                pen.EndFigure(false);
            }

            var ink = Broadsheet.Connector;
            double width = 1.0 * _scale, opacity = 0.5;

            if (_selected is { } picked)
            {
                bool down = edge.From == picked
                         || (_downstream.Contains(edge.From) && _downstream.Contains(edge.To));
                bool up = edge.To == picked
                       || (_upstream.Contains(edge.From) && _upstream.Contains(edge.To));
                if (up)        { ink = Broadsheet.InkMagenta; width = 1.5 * _scale; opacity = 0.9; }
                else if (down) { ink = Broadsheet.InkCyan;    width = 1.5 * _scale; opacity = 0.9; }
                else           { opacity = 0.16; }
            }
            links.Add((geometry, ink, Math.Max(0.6, width), opacity));
        }

        foreach (var link in links.OrderBy(l => l.Opacity))
        {
            var pen = new Pen(Broadsheet.Brush(Broadsheet.Fade(link.Ink, link.Opacity)), link.Width);
            context.DrawGeometry(null, pen, link.Path);
        }
    }

    private void DrawBoxes(DrawingContext context, Size size)
    {
        // A little slack past the edges, so a box half off-screen still draws
        // its half rather than popping in.
        var visible = new Rect(-140, -140, size.Width + 280, size.Height + 280);

        foreach (var box in _map.Boxes)
        {
            var frame = Place(box);
            if (!visible.Intersects(frame)) continue;

            var node = _map.Nodes[box.Node];
            bool isSelected = box.Node == _selected;
            bool dim = _selected is not null && !_lit.Contains(box.Node);
            double alpha = dim ? 0.32 : 1.0;

            context.FillRectangle(
                Broadsheet.Brush(isSelected
                    ? Broadsheet.InkMagentaSoft
                    : Broadsheet.Fade(Broadsheet.SurfaceRaised, alpha)),
                frame);

            // District as a rule down the left edge, not a filled header: the
            // fill is needed for selection, and two signals in one place read
            // as neither.
            context.FillRectangle(
                Broadsheet.Brush(Broadsheet.Fade(DistrictInk(node.Layer), alpha)),
                new Rect(frame.X, frame.Y, 3 * _scale, frame.Height));

            if (_scale <= 0.45) continue;

            var nameInk = isSelected ? Broadsheet.InkMagentaDeep : Broadsheet.TextPrimary;
            var name = Text(node.Name, Broadsheet.Fonts.Serif, 11.5 * _scale,
                            Broadsheet.Fade(nameInk, alpha));
            // Canvas draws whatever it is given, so a long file name has to be
            // cut to fit before it is drawn.
            // One line, cut with an ellipsis. FormattedText wraps by default,
            // and a box 21pt tall cannot show a second line — the name simply
            // spilled out of the box and over its neighbour.
            name.MaxTextWidth = Math.Max(4, frame.Width - 42 * _scale);
            name.MaxLineCount = 1;
            name.Trimming = TextTrimming.CharacterEllipsis;
            context.DrawText(name, new Point(frame.X + 10 * _scale,
                                             frame.Center.Y - name.Height / 2));

            var count = Text(node.SymbolCount.ToString(CultureInfo.InvariantCulture),
                             Broadsheet.Fonts.Mono, 10 * _scale,
                             Broadsheet.Fade(Broadsheet.TextTertiary, alpha));
            context.DrawText(count, new Point(frame.Right - 8 * _scale - count.Width,
                                              frame.Center.Y - count.Height / 2));
        }
    }

    private bool TryBox(int node, out Rect rect)
    {
        if (_boxOf.TryGetValue(node, out var box)) { rect = Place(box); return true; }
        rect = default;
        return false;
    }

    private static Color DistrictInk(string layer) => layer switch
    {
        "ui" or "entry"              => Broadsheet.InkCyan,
        "data" or "model" or "test"  => Broadsheet.InkMagenta,
        _                            => Broadsheet.TextSecondary,
    };

    private static FormattedText Text(string value, FontFamily family, double size,
                                      Color ink, FontWeight weight = FontWeight.Normal) =>
        new(value, CultureInfo.CurrentCulture, FlowDirection.LeftToRight,
            new Typeface(family, FontStyle.Normal, weight), size, Broadsheet.Brush(ink));
}
