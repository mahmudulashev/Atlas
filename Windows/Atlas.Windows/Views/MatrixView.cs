using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

/// <summary>
/// The dependency matrix: rows call columns.
///
/// No crossing lines at any size, so clusters, layers and cycles are read
/// directly off the grid rather than traced through a drawing. A cycle is not
/// inferred from which side of the diagonal a mark falls on — the reciprocal
/// pair is marked in magenta outright, which is both more direct and correct
/// for a pair sitting in the same district.
///
/// Ported from Sources/Atlas/UI/MatrixView.swift. The row order comes from
/// the engine's MatrixOrder, the same code the macOS build uses.
/// </summary>
public sealed class MatrixView : Control
{
    private const double Cell = 15;
    private const double Gap = 9;
    private const double LeftGutter = 168;
    private const double TopGutter = 152;
    private const double BarWidth = 62;

    private readonly Strings _t;
    private readonly MapInfo _map;
    private readonly IReadOnlyList<int> _order;
    private readonly Dictionary<int, int> _rank;
    private readonly HashSet<long> _calls;
    private readonly int[] _outDegree;

    private int? _selected;

    public MatrixView(Report report, Strings t)
    {
        _t = t;
        _map = report.Map ?? new MapInfo();
        _order = _map.Matrix.Order;

        _rank = new Dictionary<int, int>(_order.Count);
        for (int i = 0; i < _order.Count; i++) _rank[_order[i]] = i;

        // Membership by packed rank pair: the grid asks "is there a mark here"
        // once per cell, and a project of sixty files asks it 3,600 times a frame.
        _calls = [];
        foreach (var edge in _map.Edges)
        {
            if (_rank.TryGetValue(edge.From, out int r) && _rank.TryGetValue(edge.To, out int c))
                _calls.Add(Key(r, c));
        }

        _outDegree = new int[_order.Count];
        foreach (var edge in _map.Edges)
        {
            if (_rank.TryGetValue(edge.From, out int r)) _outDegree[r]++;
        }

        Focusable = true;
        if (Screenshot.Select is { } node && _rank.ContainsKey(node)) _selected = node;
    }

    private static long Key(int row, int column) => ((long)row << 32) | (uint)column;
    private bool Has(int row, int column) => _calls.Contains(Key(row, column));

    private static double Position(int rank, IReadOnlyList<MatrixDistrict> districts)
    {
        int gaps = 0;
        for (int i = 1; i < districts.Count; i++)
        {
            if (rank >= districts[i].Start) gaps++;
        }
        return rank * Cell + gaps * Gap;
    }

    private double Span =>
        _order.Count == 0 ? 0 : Position(_order.Count - 1, _map.Matrix.Districts) + Cell;

    protected override Size MeasureOverride(Size availableSize) =>
        _order.Count == 0
            ? new Size(400, 260)
            : new Size(LeftGutter + Span + BarWidth + 26, TopGutter + Span + 34);

    // MARK: - Interaction

    protected override void OnPointerPressed(PointerPressedEventArgs e)
    {
        base.OnPointerPressed(e);
        var point = e.GetPosition(this);
        var districts = _map.Matrix.Districts;

        for (int rank = 0; rank < _order.Count; rank++)
        {
            double o = Position(rank, districts);
            bool onRow = point.Y >= TopGutter + o && point.Y < TopGutter + o + Cell;
            bool onColumn = point.X >= LeftGutter + o && point.X < LeftGutter + o + Cell;
            if ((onRow && point.X < LeftGutter)
                || (onColumn && point.Y < TopGutter)
                || (onRow && point.X >= LeftGutter))
            {
                int node = _order[rank];
                _selected = _selected == node ? null : node;
                InvalidateVisual();
                return;
            }
        }
        _selected = null;
        InvalidateVisual();
    }

    // MARK: - Drawing

    public override void Render(DrawingContext context)
    {
        if (_order.Count == 0) return;

        var districts = _map.Matrix.Districts;
        int count = _order.Count;
        double span = Span;
        int? selectedRank = _selected is { } picked && _rank.TryGetValue(picked, out int r)
            ? r : null;

        // Bands for the selection: the row it calls in cyan, the column that
        // calls it in magenta. The same pairing as everywhere else.
        if (selectedRank is { } rank)
        {
            double at = Position(rank, districts);
            context.FillRectangle(Broadsheet.Brush(Broadsheet.Fade(Broadsheet.InkCyan, 0.11)),
                new Rect(LeftGutter, TopGutter + at, span, Cell));
            context.FillRectangle(Broadsheet.Brush(Broadsheet.Fade(Broadsheet.InkMagenta, 0.09)),
                new Rect(LeftGutter + at, TopGutter, Cell, span));
        }

        // ---- Cells ----
        var diagonalBrush = Broadsheet.Brush(Broadsheet.Border);
        for (int row = 0; row < count; row++)
        {
            double y = TopGutter + Position(row, districts);
            for (int column = 0; column < count; column++)
            {
                double x = LeftGutter + Position(column, districts);

                if (row == column)
                {
                    // The file itself: a small neutral square, well inside the
                    // cell so it never reads as data.
                    context.FillRectangle(diagonalBrush, new Rect(x + 5, y + 5, 5, 5));
                    continue;
                }
                if (!Has(row, column)) continue;

                bool reciprocal = Has(column, row);
                bool live = selectedRank == row || selectedRank == column;
                var ink = reciprocal ? Broadsheet.InkMagenta : Broadsheet.InkCyan;
                context.FillRectangle(
                    Broadsheet.Brush(Broadsheet.Fade(ink, live ? 1 : 0.78)),
                    new Rect(x + 1, y + 1, 13, 13));
            }
        }

        // ---- Fan bars: how many files each row pulls in ----
        int maxOut = Math.Max(_outDegree.Length == 0 ? 1 : _outDegree.Max(), 1);
        var barBrush = Broadsheet.Brush(Broadsheet.BorderStrong);
        for (int i = 0; i < _outDegree.Length; i++)
        {
            double width = (double)_outDegree[i] / maxOut * BarWidth;
            if (width <= 0.5) continue;
            context.FillRectangle(barBrush,
                new Rect(LeftGutter + span + 10, TopGutter + Position(i, districts) + 4,
                         width, 7));
        }

        // ---- Row labels ----
        for (int i = 0; i < count; i++)
        {
            var label = Label(_order[i], selectedRank == i);
            context.DrawText(label,
                new Point(LeftGutter - 10 - label.Width,
                          TopGutter + Position(i, districts) + Cell / 2 - label.Height / 2));
        }

        // ---- Column labels, turned ----
        for (int i = 0; i < count; i++)
        {
            var label = Label(_order[i], selectedRank == i);
            var at = new Point(LeftGutter + Position(i, districts) + 11, TopGutter - 6);
            using (context.PushTransform(
                       Matrix.CreateRotation(-Math.PI / 2) * Matrix.CreateTranslation(at.X, at.Y)))
            {
                context.DrawText(label, new Point(0, -label.Height / 2));
            }
        }

        // ---- District marks, below the grid ----
        foreach (var district in districts)
        {
            var text = Text(DistrictLabel(district.Key).ToUpperInvariant(), 10,
                            DistrictInk(district.Key), FontWeight.SemiBold);
            context.DrawText(text,
                new Point(LeftGutter + Position(district.Start, districts), TopGutter + span + 12));
        }
    }

    private FormattedText Label(int node, bool selected) =>
        Text(node >= 0 && node < _map.Nodes.Count ? _map.Nodes[node].Name : "",
             10.5, selected ? Broadsheet.TextPrimary : Broadsheet.TextSecondary);

    private string DistrictLabel(string key) => key switch
    {
        "interface" => _t["districtInterface"],
        "data"      => _t["districtData"],
        _           => _t["districtLogic"],
    };

    private static Color DistrictInk(string key) => key switch
    {
        "interface" => Broadsheet.InkCyan,
        "data"      => Broadsheet.InkMagenta,
        _           => Broadsheet.TextSecondary,
    };

    private static FormattedText Text(string value, double size, Color ink,
                                      FontWeight weight = FontWeight.Normal) =>
        new(value, CultureInfo.CurrentCulture, FlowDirection.LeftToRight,
            new Typeface(Broadsheet.Fonts.Serif, FontStyle.Normal, weight),
            size, Broadsheet.Brush(ink));
}
