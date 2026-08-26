using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

/// <summary>
/// "What this does" — the panel a junior developer actually reads.
///
/// Ported from ExplainPanel.swift, minus the on-device model: that is Apple's
/// and has no counterpart here. What is left is what the macOS app shows on
/// every machine anyway — the explanation derived from the graph, how hard the
/// code is likely to be, who calls it, and how far a change would reach.
/// </summary>
public sealed class InspectorView : UserControl
{
    public InspectorView(Report report, Strings t, int symbolIndex, SourceSnippet? snippet,
                         Settings? settings = null, Action? onToggleRead = null)
    {
        var column = new StackPanel { Spacing = 18 };

        if (symbolIndex < 0 || symbolIndex >= report.Symbols.Count)
        {
            column.Children.Add(Caption(t["pickSomething"], Broadsheet.TextTertiary));
        }
        else
        {
            var symbol = report.Symbols[symbolIndex];
            column.Children.Add(Section(t["whatThisDoes"],
                RichText.Block(symbol.Explanation, Broadsheet.Fonts.Caption,
                               Broadsheet.TextSecondary)));
            column.Children.Add(Section(t["howHard"], Difficulty(symbol, t)));
            column.Children.Add(Section(t["theFacts"], Facts(report, t, symbolIndex, symbol)));

            if (snippet is { Glossary.Count: > 0 })
            {
                column.Children.Add(Section(t["glossary"], Terms(snippet.Glossary)));
            }

            if (settings is not null && onToggleRead is not null)
            {
                column.Children.Add(ReadMark(report, t, symbolIndex, settings, onToggleRead));
            }
        }

        Content = new ScrollViewer
        {
            HorizontalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Disabled,
            Content = new Border { Padding = new Thickness(16, 16), Child = column },
        };
        Background = Broadsheet.Brush(Broadsheet.Surface);
    }

    /// <summary>
    /// Marking a declaration read. Progress a reader keeps themselves, rather
    /// than the app guessing from what has been scrolled past.
    /// </summary>
    private static Control ReadMark(Report report, Strings t, int index,
                                    Settings settings, Action onToggle)
    {
        string root = report.Project.Root;
        string signature = Settings.Signature(report, index);
        bool read = settings.IsUnderstood(root, signature);

        var button = new Button
        {
            Content = new TextBlock
            {
                Text = read ? $"✓ {t["understoodMark"]}" : t["understood"],
                FontFamily = Broadsheet.Fonts.Serif,
                FontSize = Broadsheet.Fonts.Caption,
                Foreground = Broadsheet.Brush(read ? Broadsheet.Accent : Broadsheet.TextSecondary),
            },
            Background = Broadsheet.Brush(read ? Broadsheet.AccentMuted : Broadsheet.SurfaceRaised),
            BorderBrush = Broadsheet.Brush(read ? Broadsheet.Accent : Broadsheet.Border),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(Broadsheet.Metric.Radius),
            Padding = new Thickness(12, 6),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 6, 0, 0),
        };
        button.Click += (_, _) => { settings.ToggleUnderstood(root, signature); onToggle(); };
        return button;
    }

    private static Control Section(string title, Control body)
    {
        var stack = new StackPanel { Spacing = 8 };
        stack.Children.Add(new Rule(title));
        stack.Children.Add(body);
        return stack;
    }

    /// <summary>
    /// Three rising bars. A number ("complexity 7") means nothing without a
    /// scale to compare it against; rising bars are read instantly and need no
    /// legend. From PaperBackground.swift's TerrainMark.
    /// </summary>
    private static Control Difficulty(SymbolEntry symbol, Strings t)
    {
        int level = symbol.Difficulty switch { "hard" => 2, "moderate" => 1, _ => 0 };
        var ink = Broadsheet.ForDifficulty(symbol.Difficulty);

        var bars = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 1.5,
            VerticalAlignment = VerticalAlignment.Bottom,
        };
        for (int step = 0; step < 3; step++)
        {
            bars.Children.Add(new Border
            {
                Width = 3,
                Height = 5 + step * 3,
                CornerRadius = new CornerRadius(0.5),
                Background = Broadsheet.Brush(step <= level ? ink : Broadsheet.Border),
                VerticalAlignment = VerticalAlignment.Bottom,
            });
        }

        var name = new TextBlock
        {
            Text = t[symbol.Difficulty switch
            {
                "hard" => "difficultyHard",
                "moderate" => "difficultyModerate",
                _ => "difficultyEasy",
            }],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Caption,
            Foreground = Broadsheet.Brush(ink),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(8, 0, 0, 0),
        };

        var row = new StackPanel { Orientation = Orientation.Horizontal };
        row.Children.Add(bars);
        row.Children.Add(name);
        return row;
    }

    /// <summary>
    /// Counted here rather than sent: these are queries over the call edges the
    /// report already carries, not analysis. Nothing is being re-derived — the
    /// graph came from the engine and this only walks it.
    /// </summary>
    private static Control Facts(Report report, Strings t, int index, SymbolEntry symbol)
    {
        var callers = report.Calls.Where(c => c.To == index).Select(c => c.From).Distinct().ToList();
        var callees = report.Calls.Where(c => c.From == index).Select(c => c.To).Distinct().ToList();

        var stack = new StackPanel { Spacing = 5 };
        stack.Children.Add(Fact(t["callers"], callers.Count, Broadsheet.InkMagentaDeep));
        stack.Children.Add(Fact(t["callees"], callees.Count, Broadsheet.InkCyanDeep));

        var (reachedSymbols, reachedFiles) = Blast(report, index, hops: 2);
        stack.Children.Add(new TextBlock
        {
            Text = t["blastTitle"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            FontWeight = FontWeight.SemiBold,
            LetterSpacing = 0.8,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            Margin = new Thickness(0, 8, 0, 0),
        });
        stack.Children.Add(Caption(
            $"{reachedSymbols} · {reachedFiles}", Broadsheet.TextSecondary));

        if (symbol.File >= 0 && symbol.File < report.Files.Count)
        {
            stack.Children.Add(Caption(
                $"{report.Files[symbol.File].Path}:{symbol.Line}", Broadsheet.TextTertiary));
        }
        return stack;
    }

    private static Control Fact(string label, int count, Color ink)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        row.Children.Add(new TextBlock
        {
            Text = count.ToString(CultureInfo.InvariantCulture),
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.MonoSize,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(ink),
            Width = 32,
            TextAlignment = TextAlignment.Right,
        });
        row.Children.Add(new TextBlock
        {
            Text = label,
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Caption,
            Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
            VerticalAlignment = VerticalAlignment.Center,
        });
        return row;
    }

    /// <summary>What a change here could reach, within a few hops.</summary>
    private static (int Symbols, int Files) Blast(Report report, int index, int hops)
    {
        var seen = new HashSet<int> { index };
        var frontier = new List<int> { index };
        for (int hop = 0; hop < hops && frontier.Count > 0; hop++)
        {
            var next = new List<int>();
            foreach (var call in report.Calls)
            {
                // Reach runs against the arrows: a change here is felt by
                // whoever calls it, not by what it calls.
                if (frontier.Contains(call.To) && seen.Add(call.From)) next.Add(call.From);
            }
            frontier = next;
        }
        var files = seen
            .Where(s => s >= 0 && s < report.Symbols.Count)
            .Select(s => report.Symbols[s].File)
            .Where(f => f >= 0)
            .Distinct().Count();
        return (seen.Count - 1, files);
    }

    private static Control Terms(IReadOnlyList<GlossaryTerm> terms)
    {
        var stack = new StackPanel { Spacing = 9 };
        foreach (var term in terms)
        {
            var one = new StackPanel { Spacing = 2 };
            one.Children.Add(new TextBlock
            {
                Text = term.Title,
                FontFamily = Broadsheet.Fonts.Mono,
                FontSize = Broadsheet.Fonts.MonoSmall,
                FontWeight = FontWeight.Medium,
                Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
            });
            one.Children.Add(RichText.Block(term.Body, Broadsheet.Fonts.Caption,
                                            Broadsheet.TextSecondary));
            stack.Children.Add(one);
        }
        return stack;
    }

    private static TextBlock Caption(string text, Color ink) => new()
    {
        Text = text,
        FontFamily = Broadsheet.Fonts.Serif,
        FontSize = Broadsheet.Fonts.Caption,
        Foreground = Broadsheet.Brush(ink),
        TextWrapping = TextWrapping.Wrap,
        LineHeight = 18,
    };
}
