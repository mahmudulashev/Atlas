using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

/// <summary>
/// The findings list: what in this codebase is worth a second look.
///
/// Every row points at a real file and line, because a report you cannot act
/// on is just a source of guilt. Ported from Sources/Atlas/UI/IssuesView.swift.
/// </summary>
public sealed class IssuesView : UserControl
{
    public IssuesView(Report report, Strings t)
    {
        var column = new StackPanel
        {
            HorizontalAlignment = HorizontalAlignment.Left,
            MaxWidth = 760,
            Spacing = 22,
        };
        column.Children.Add(Header(report, t));

        if (report.Issues.Count == 0)
        {
            column.Children.Add(Empty(t));
        }
        else
        {
            // Most severe first — the order the reader should spend attention in.
            foreach (var severity in new[] { "high", "medium", "low" })
            {
                var group = report.Issues.Where(i => i.Severity == severity).ToList();
                if (group.Count == 0) continue;
                column.Children.Add(Section(severity, group, t));
            }
        }

        Content = new ScrollViewer
        {
            HorizontalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Disabled,
            Content = new Border { Padding = new Thickness(40, 32), Child = column },
        };
    }

    private static Control Header(Report report, Strings t)
    {
        var line = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
        line.Children.Add(new TextBlock
        {
            Text = t["issuesTitle"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Display,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
        });
        line.Children.Add(new TextBlock
        {
            Text = report.Issues.Count.ToString(System.Globalization.CultureInfo.InvariantCulture),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Number,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            VerticalAlignment = VerticalAlignment.Bottom,
        });

        var stack = new StackPanel { Spacing = 8 };
        stack.Children.Add(line);
        stack.Children.Add(new TextBlock
        {
            Text = t["issuesHint"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Caption,
            Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
            TextWrapping = TextWrapping.Wrap,
            LineHeight = 19,
        });
        return stack;
    }

    private static Control Empty(Strings t) => new TextBlock
    {
        Text = t["issuesNone"],
        FontFamily = Broadsheet.Fonts.Serif,
        FontSize = Broadsheet.Fonts.Body,
        Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
        TextWrapping = TextWrapping.Wrap,
        Margin = new Thickness(0, 30),
    };

    private static Control Section(string severity, List<IssueEntry> issues, Strings t)
    {
        var tint = Tint(severity);

        var head = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 7,
            VerticalAlignment = VerticalAlignment.Center,
        };
        head.Children.Add(new Border
        {
            Width = 3, Height = 12,
            CornerRadius = new CornerRadius(1.5),
            Background = Broadsheet.Brush(tint),
            VerticalAlignment = VerticalAlignment.Center,
        });
        head.Children.Add(new TextBlock
        {
            Text = t[SeverityKey(severity)].ToUpperInvariant(),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            FontWeight = FontWeight.Bold,
            LetterSpacing = 0.9,
            Foreground = Broadsheet.Brush(tint),
            VerticalAlignment = VerticalAlignment.Center,
        });
        head.Children.Add(new TextBlock
        {
            Text = issues.Count.ToString(System.Globalization.CultureInfo.InvariantCulture),
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            VerticalAlignment = VerticalAlignment.Center,
        });

        var rows = new StackPanel { Spacing = 5, Margin = new Thickness(0, 7, 0, 0) };
        foreach (var issue in issues) rows.Children.Add(Row(issue, tint));

        var stack = new StackPanel();
        stack.Children.Add(head);
        stack.Children.Add(rows);
        return stack;
    }

    private static Control Row(IssueEntry issue, Color tint)
    {
        var title = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        title.Children.Add(new TextBlock
        {
            Text = issue.Title,
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Caption,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
        });
        title.Children.Add(new TextBlock
        {
            Text = issue.Measurement,
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            VerticalAlignment = VerticalAlignment.Center,
        });

        var body = new StackPanel { Spacing = 3, Margin = new Thickness(0, 9, 10, 9) };
        body.Children.Add(title);
        if (issue.Subject.Length > 0)
        {
            body.Children.Add(new TextBlock
            {
                Text = issue.Subject,
                FontFamily = Broadsheet.Fonts.Mono,
                FontSize = Broadsheet.Fonts.MonoSmall,
                Foreground = Broadsheet.Brush(tint),
                TextTrimming = TextTrimming.CharacterEllipsis,
            });
        }
        body.Children.Add(RichText.Block(issue.Advice, Broadsheet.Fonts.Micro,
                                         Broadsheet.TextSecondary, lineHeight: 15));
        if (issue.File.Length > 0)
        {
            body.Children.Add(new TextBlock
            {
                Text = $"{issue.File}:{issue.Line}",
                FontFamily = Broadsheet.Fonts.Serif,
                FontSize = Broadsheet.Fonts.Micro,
                Foreground = Broadsheet.Brush(Broadsheet.Fade(Broadsheet.TextTertiary, 0.8)),
                TextTrimming = TextTrimming.CharacterEllipsis,
            });
        }

        var rule = new Border
        {
            Width = 3,
            Background = Broadsheet.Brush(tint),
            CornerRadius = new CornerRadius(2),
            Margin = new Thickness(0, 0, 11, 0),
        };

        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*") };
        Grid.SetColumn(rule, 0);
        Grid.SetColumn(body, 1);
        row.Children.Add(rule);
        row.Children.Add(body);

        return new Border
        {
            Background = Broadsheet.Brush(Broadsheet.Surface),
            BorderBrush = Broadsheet.Brush(Broadsheet.Border),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(8),
            Child = row,
        };
    }

    /// <summary>
    /// Severity is set in weight, not in a hue: both process inks already mean
    /// a direction, and a red would start competing with them.
    /// </summary>
    private static Color Tint(string severity) => severity switch
    {
        "high"   => Broadsheet.Marker,
        "medium" => Broadsheet.Gold,
        _        => Broadsheet.TextTertiary,
    };

    private static string SeverityKey(string severity) => severity switch
    {
        "high"   => "severityHigh",
        "medium" => "severityMedium",
        _        => "severityLow",
    };
}
