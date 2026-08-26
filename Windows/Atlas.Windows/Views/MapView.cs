using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

/// <summary>
/// The ladder with its chrome: what it is, what the inks mean, and the zoom.
///
/// The legend is not decoration. Cyan and magenta carry direction everywhere
/// in Atlas, and a reader meeting the Map first has no way to know that —
/// which would leave the drawing looking merely colourful.
/// </summary>
public sealed class MapView : UserControl
{
    private readonly LadderView _ladder;
    private readonly Strings _t;
    private readonly TextBlock _selectionNote;

    public MapView(Report report, Strings t)
    {
        _t = t;
        _ladder = new LadderView(report, t);

        _selectionNote = new TextBlock
        {
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            VerticalAlignment = VerticalAlignment.Center,
        };
        _ladder.SelectionChanged += UpdateSelectionNote;
        UpdateSelectionNote();

        Content = new Panel
        {
            Children =
            {
                new PaperBackground(),
                _ladder,
                Header(),
                Legend(),
                Controls(),
            },
        };
    }

    private void UpdateSelectionNote() =>
        _selectionNote.Text = _ladder.Selected is null
            ? _t["clickAnyFile"]
            : _t.Format("ladderSelection", _ladder.UpstreamCount, _ladder.DownstreamCount);

    private Control Header()
    {
        var stack = new StackPanel
        {
            Spacing = 3,
            MaxWidth = 620,
            HorizontalAlignment = HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(16, 12, 0, 0),
        };
        stack.Children.Add(new TextBlock
        {
            Text = _t["ladderTitle"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Heading,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
        });
        stack.Children.Add(new TextBlock
        {
            Text = _t["ladderHint"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            TextWrapping = TextWrapping.Wrap,
            LineHeight = 15,
        });
        return stack;
    }

    private Control Legend()
    {
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 16,
            HorizontalAlignment = HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Bottom,
            Margin = new Thickness(16, 0, 0, 14),
        };

        // Districts first — the rule down each box's left edge.
        foreach (var (key, ink) in new[]
                 {
                     ("districtInterface", Broadsheet.InkCyan),
                     ("districtLogic", Broadsheet.TextSecondary),
                     ("districtData", Broadsheet.InkMagenta),
                 })
        {
            row.Children.Add(Key(new Border
            {
                Width = 3, Height = 11,
                Background = Broadsheet.Brush(ink),
                VerticalAlignment = VerticalAlignment.Center,
            }, _t[key]));
        }

        // Then what the two inks mean when something is selected, which is the
        // part that actually needs saying.
        row.Children.Add(Key(Line(Broadsheet.InkMagenta), _t["reachesSelection"]));
        row.Children.Add(Key(Line(Broadsheet.InkCyan), _t["selectionReaches"]));
        row.Children.Add(_selectionNote);
        return row;
    }

    private static Control Line(Color ink) => new Border
    {
        Width = 14, Height = 1.5,
        Background = Broadsheet.Brush(ink),
        VerticalAlignment = VerticalAlignment.Center,
    };

    private static Control Key(Control mark, string label)
    {
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 6,
            VerticalAlignment = VerticalAlignment.Center,
        };
        row.Children.Add(mark);
        row.Children.Add(new TextBlock
        {
            Text = label,
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            VerticalAlignment = VerticalAlignment.Center,
        });
        return row;
    }

    private Control Controls()
    {
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 6,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Bottom,
            Margin = new Thickness(0, 0, 14, 14),
        };
        row.Children.Add(Action("−", _t["zoomOut"], () => _ladder.Zoom(1 / 1.25)));
        row.Children.Add(Action("+", _t["zoomIn"], () => _ladder.Zoom(1.25)));
        row.Children.Add(Action("⤢", _t["fitToScreen"], _ladder.FitToScreen));
        return row;
    }

    private static Control Action(string glyph, string tip, Action press)
    {
        var button = new Button
        {
            Content = new TextBlock
            {
                Text = glyph,
                FontFamily = Broadsheet.Fonts.Serif,
                FontSize = Broadsheet.Fonts.Caption,
                Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
            },
            Background = Broadsheet.Brush(Broadsheet.SurfaceRaised),
            BorderBrush = Broadsheet.Brush(Broadsheet.Border),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(Broadsheet.Metric.Radius),
            Padding = new Thickness(9, 4),
            [ToolTip.TipProperty] = tip,
        };
        button.Click += (_, _) => press();
        return button;
    }
}
