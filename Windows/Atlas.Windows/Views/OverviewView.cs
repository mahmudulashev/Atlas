using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Documents;
using Avalonia.Layout;
using Avalonia.Media;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

/// <summary>
/// The Atlas: what this project is, how big, and where to start.
///
/// Set as the opening page of a printed chart — a masthead, a row of figures,
/// then the two things a newcomer actually needs. Ported from
/// Sources/Atlas/UI/OverviewView.swift.
/// </summary>
public sealed class OverviewView : UserControl
{
    private const double ColumnWidth = 780;

    public OverviewView(Report report, Strings t)
    {
        var column = new StackPanel
        {
            HorizontalAlignment = HorizontalAlignment.Left,
            MaxWidth = ColumnWidth,
            Spacing = 0,
        };
        column.Children.Add(Masthead(report, t));
        column.Children.Add(Figures(report, t));
        column.Children.Add(StartHere(report, t));
        column.Children.Add(DriftSection(report, t));
        column.Children.Add(Districts(report, t));

        Content = new ScrollViewer
        {
            HorizontalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Disabled,
            Content = new Border
            {
                Padding = new Thickness(44, 38),
                Child = column,
            },
        };
    }

    // MARK: - Masthead

    private static Control Masthead(Report report, Strings t)
    {
        var title = new TextBlock
        {
            Text = report.Project.Name,
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Display,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
        };

        var path = new TextBlock
        {
            Text = ShortPath(report.Project.Root),
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.MonoSmall,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            // The tail of a path is the informative half, so a long one loses
            // its head rather than its file.
            TextTrimming = TextTrimming.CharacterEllipsis,
            VerticalAlignment = VerticalAlignment.Bottom,
            Margin = new Thickness(12, 0, 0, 4),
        };

        var heading = new StackPanel { Orientation = Orientation.Horizontal };
        heading.Children.Add(title);
        heading.Children.Add(path);

        // "This is a web framework. A framework is …" — the kind is set in the
        // downstream ink because it is the answer, and the rest is context.
        var sentence = new TextBlock
        {
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = 16,
            TextWrapping = TextWrapping.Wrap,
            LineHeight = 24,
            Margin = new Thickness(0, 12, 0, 0),
        };
        sentence.Inlines =
        [
            new Run(t["projectIs"] + " ")
                { Foreground = Broadsheet.Brush(Broadsheet.TextPrimary) },
            new Run(report.Project.KindLabel)
                { Foreground = Broadsheet.Brush(Broadsheet.InkCyanDeep),
                  FontWeight = FontWeight.SemiBold },
            new Run(". " + report.Project.KindExplanation)
                { Foreground = Broadsheet.Brush(Broadsheet.TextSecondary) },
        ];

        var stack = new StackPanel();
        stack.Children.Add(heading);
        stack.Children.Add(sentence);
        return stack;
    }

    private static string ShortPath(string root)
    {
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)
                              .Replace('\\', '/');
        var shown = root.Replace('\\', '/');
        return home.Length > 0 && shown.StartsWith(home, StringComparison.Ordinal)
            ? "~" + shown[home.Length..]
            : shown;
    }

    // MARK: - Figures

    private static Control Figures(Report report, Strings t)
    {
        var project = report.Project;

        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 34,
            Margin = new Thickness(0, 12, 0, 0),
        };
        row.Children.Add(Figure(Strings.Count(project.FileCount), t["files"]));
        row.Children.Add(Figure(Strings.Count(project.LineCount), t["lines"]));
        row.Children.Add(Figure(Strings.Count(project.SymbolCount), t["symbols"]));
        row.Children.Add(Figure(Strings.Count(project.CallCount), t["callEdges"]));

        var footnote = new TextBlock
        {
            Text = t["everyFigure"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 12, 0, 0),
        };

        var stack = new StackPanel { Margin = new Thickness(0, 30, 0, 0) };
        stack.Children.Add(new Rule(t["shapeOfIt"]));
        stack.Children.Add(row);
        stack.Children.Add(footnote);
        return stack;
    }

    private static Control Figure(string value, string label)
    {
        var stack = new StackPanel { Spacing = 1 };
        stack.Children.Add(new TextBlock
        {
            Text = value,
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Number,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
        });
        stack.Children.Add(new TextBlock
        {
            Text = label.ToUpperInvariant(),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Label,
            FontWeight = FontWeight.SemiBold,
            LetterSpacing = Broadsheet.Fonts.LabelTracking,
            Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
        });
        return stack;
    }

    // MARK: - Start here

    private static Control StartHere(Report report, Strings t)
    {
        var stack = new StackPanel { Margin = new Thickness(0, 34, 0, 0) };

        if (report.Route.Count == 0)
        {
            // A project with no clear entry point is a real outcome, not an
            // error — say so instead of hiding the section.
            stack.Children.Add(new Rule(t["startHere"]));
            stack.Children.Add(Caption(t["routeEmpty"], Broadsheet.TextTertiary, 520));
            return stack;
        }

        stack.Children.Add(new Rule(t["startHere"]));
        stack.Children.Add(Caption(t["startHereBlurb"], Broadsheet.TextSecondary, 560));

        var rows = new StackPanel { Margin = new Thickness(0, 4, 0, 0) };
        int shown = Math.Min(4, report.Route.Count);
        for (int i = 0; i < shown; i++)
        {
            var step = report.Route[i];
            var symbol = report.Symbols[step.Symbol];
            rows.Children.Add(EntryRow(i + 1, symbol, Place(symbol, report), step.Reach,
                                       isLast: i == shown - 1, t));
        }
        stack.Children.Add(rows);
        return stack;
    }

    private static string Place(SymbolEntry symbol, Report report) =>
        symbol.File >= 0 && symbol.File < report.Files.Count
            ? $"{report.Files[symbol.File].Path}:{symbol.Line}"
            : "";

    private static Control EntryRow(int number, SymbolEntry symbol, string place,
                                    int reach, bool isLast, Strings t)
    {
        var ordinal = new TextBlock
        {
            Text = number.ToString(CultureInfo.InvariantCulture),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = 22,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            Width = 22,
            TextAlignment = TextAlignment.Right,
        };

        var name = new TextBlock
        {
            Text = symbol.Display,
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.MonoSize,
            FontWeight = FontWeight.Medium,
            Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        var where = new TextBlock
        {
            Text = place,
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        var middle = new StackPanel { Spacing = 1 };
        middle.Children.Add(name);
        middle.Children.Add(where);

        // Reach is set in the downstream ink, because that is what it counts.
        var reaches = new TextBlock
        {
            Text = t.Format("reaches", reach),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.InkCyanDeep),
            VerticalAlignment = VerticalAlignment.Center,
        };
        var arrow = new TextBlock
        {
            Text = t["readArrow"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(10, 0, 0, 0),
        };

        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("22,14,*,Auto,Auto") };
        Grid.SetColumn(ordinal, 0);
        Grid.SetColumn(middle, 2);
        Grid.SetColumn(reaches, 3);
        Grid.SetColumn(arrow, 4);
        row.Children.Add(ordinal);
        row.Children.Add(middle);
        row.Children.Add(reaches);
        row.Children.Add(arrow);

        return new Border
        {
            Padding = new Thickness(0, 9),
            BorderThickness = new Thickness(0, 0, 0, isLast ? 0 : 1),
            BorderBrush = Broadsheet.Brush(Broadsheet.BorderSoft),
            Child = row,
        };
    }

    // MARK: - Drift

    /// <summary>
    /// The only section with a memory. It opens the Atlas because "what moved
    /// since I was away" is the first question on returning to a project, and
    /// nothing else here can answer it.
    /// </summary>
    private static Control DriftSection(Report report, Strings t)
    {
        var stack = new StackPanel { Margin = new Thickness(0, 34, 0, 0) };

        // A Grid, not a horizontal stack: the rule's hairline runs on whatever
        // is left over, and a stack would only give it its desired width —
        // which for a hairline is nothing.
        var head = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        var rule = new Rule(t["driftTitle"]);
        Grid.SetColumn(rule, 0);
        head.Children.Add(rule);
        if (report.Drift?.PreviousScan is { } since)
        {
            var stamp = new TextBlock
            {
                Text = t.Format("driftSince", since.ToString("d MMM", CultureInfo.CurrentCulture)),
                FontFamily = Broadsheet.Fonts.Serif,
                FontSize = Broadsheet.Fonts.Micro,
                Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(10, 0, 0, 0),
            };
            Grid.SetColumn(stamp, 1);
            head.Children.Add(stamp);
        }
        stack.Children.Add(head);

        var entries = report.Drift?.Entries ?? [];
        if (entries.Count == 0)
        {
            stack.Children.Add(Caption(
                report.Drift?.PreviousScan is null ? t["driftFirst"] : t["driftNone"],
                Broadsheet.TextTertiary, 560));
            return stack;
        }

        var rows = new StackPanel { Margin = new Thickness(0, 6, 0, 0) };
        foreach (var entry in entries.Take(6)) rows.Children.Add(DriftRow(entry));
        stack.Children.Add(rows);
        return stack;
    }

    private static Control DriftRow(DriftEntry entry)
    {
        // Structural regressions take the upstream ink, because a new cycle is
        // something reaching back; improvements take the downstream one.
        var ink = entry.Regression ? Broadsheet.InkMagentaDeep
                : entry.Improvement ? Broadsheet.InkCyanDeep
                : Broadsheet.TextPrimary;

        var figure = new TextBlock
        {
            Text = entry.Kind == "newCycle" ? "+1"
                 : entry.Delta >= 0 ? $"+{entry.Delta}"
                 : $"−{Math.Abs(entry.Delta)}",
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = 17,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(ink),
            Width = 46,
            TextAlignment = TextAlignment.Right,
        };
        // Some kinds count the whole project rather than one symbol and carry
        // no subject at all; there the sentence is the entire row.
        var words = new StackPanel { Spacing = 1, Margin = new Thickness(14, 0, 0, 0) };
        if (entry.Subject.Length > 0)
        {
            words.Children.Add(new TextBlock
            {
                Text = entry.Subject,
                FontFamily = Broadsheet.Fonts.Mono,
                FontSize = Broadsheet.Fonts.MonoSize,
                FontWeight = FontWeight.Medium,
                Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
                TextTrimming = TextTrimming.CharacterEllipsis,
            });
        }
        words.Children.Add(new TextBlock
        {
            Text = entry.Note,
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Caption,
            Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
            TextWrapping = TextWrapping.Wrap,
        });

        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("46,*") };
        Grid.SetColumn(figure, 0);
        Grid.SetColumn(words, 1);
        row.Children.Add(figure);
        row.Children.Add(words);

        return new Border
        {
            Padding = new Thickness(0, 9),
            BorderThickness = new Thickness(0, 0, 0, 1),
            BorderBrush = Broadsheet.Brush(Broadsheet.BorderSoft),
            Child = row,
        };
    }

    // MARK: - Districts

    /// <summary>
    /// How the codebase divides. Files carry a layer already — the Map colours
    /// by it — but until now nothing said how much of the project sits in
    /// each, which is the first thing you want to know about a stranger's
    /// repository.
    /// </summary>
    private static Control Districts(Report report, Strings t)
    {
        var nodes = report.Diagram?.Nodes ?? [];
        var stack = new StackPanel { Margin = new Thickness(0, 34, 0, 0) };
        if (nodes.Count == 0) return stack;

        // Three districts, not nine: the reader wants the shape, and the finer
        // layer classification is already carried by the Map's colours.
        (string Title, Color Ink, string[] Layers)[] buckets =
        [
            (t["districtInterface"], Broadsheet.ForKind("initializer"), ["ui", "entry"]),
            (t["districtLogic"],     Broadsheet.TextSecondary,          ["logic", "api", "util", "config"]),
            (t["districtData"],      Broadsheet.ForKind("type"),        ["data", "model", "test"]),
        ];

        int total = Math.Max(nodes.Sum(n => n.SymbolCount), 1);

        stack.Children.Add(new Rule(t["districts"]));
        var rows = new StackPanel();
        foreach (var (title, ink, layers) in buckets)
        {
            var members = nodes.Where(n => layers.Contains(n.Layer)).ToList();
            if (members.Count == 0) continue;
            int symbols = members.Sum(n => n.SymbolCount);
            string names = string.Join(" · ", members
                .OrderByDescending(n => n.FanIn + n.FanOut)
                .Take(3).Select(n => n.Name));
            rows.Children.Add(DistrictRow(title, ink, members.Count, symbols,
                                          (double)symbols / total, names));
        }
        stack.Children.Add(rows);
        return stack;
    }

    private static Control DistrictRow(string title, Color ink, int files, int symbols,
                                       double share, string names)
    {
        var label = new TextBlock
        {
            Text = title.ToUpperInvariant(),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Label,
            FontWeight = FontWeight.SemiBold,
            LetterSpacing = 1.0,
            Foreground = Broadsheet.Brush(ink),
            Width = 84,
            Margin = new Thickness(0, 2, 0, 0),
        };

        // A share bar rather than a percentage: the comparison between
        // districts is the point, not the number.
        double filled = Math.Clamp(share, 0, 1);
        var bar = new Grid
        {
            Height = 6,
            ColumnDefinitions = new ColumnDefinitions(string.Create(
                CultureInfo.InvariantCulture, $"{filled:0.####}*,{1 - filled:0.####}*")),
        };
        var track = new Border { Background = Broadsheet.Brush(Broadsheet.BorderSoft) };
        Grid.SetColumnSpan(track, 2);
        var fill = new Border { Background = Broadsheet.Brush(Broadsheet.Fade(ink, 0.55)) };
        Grid.SetColumn(fill, 0);
        bar.Children.Add(track);
        bar.Children.Add(fill);

        var middle = new StackPanel { Spacing = 4 };
        middle.Children.Add(bar);
        middle.Children.Add(new TextBlock
        {
            Text = names,
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            TextTrimming = TextTrimming.CharacterEllipsis,
        });

        var counts = new TextBlock
        {
            Text = $"{files} · {symbols}",
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.MonoSmall,
            Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
            Width = 66,
            TextAlignment = TextAlignment.Right,
            Margin = new Thickness(0, 1, 0, 0),
        };

        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("84,14,*,66") };
        Grid.SetColumn(label, 0);
        Grid.SetColumn(middle, 2);
        Grid.SetColumn(counts, 3);
        row.Children.Add(label);
        row.Children.Add(middle);
        row.Children.Add(counts);

        return new Border
        {
            Padding = new Thickness(0, 9),
            BorderThickness = new Thickness(0, 0, 0, 1),
            BorderBrush = Broadsheet.Brush(Broadsheet.BorderSoft),
            Child = row,
        };
    }

    private static TextBlock Caption(string text, Color ink, double maxWidth) => new()
    {
        Text = text,
        FontFamily = Broadsheet.Fonts.Serif,
        FontSize = Broadsheet.Fonts.Caption,
        Foreground = Broadsheet.Brush(ink),
        TextWrapping = TextWrapping.Wrap,
        LineHeight = 18,
        MaxWidth = maxWidth,
        HorizontalAlignment = HorizontalAlignment.Left,
        Margin = new Thickness(0, 8, 0, 0),
    };
}
