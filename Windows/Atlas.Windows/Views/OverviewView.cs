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
}
