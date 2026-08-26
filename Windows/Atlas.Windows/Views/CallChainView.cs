using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

/// <summary>
/// The path execution takes to reach what you are reading.
///
/// Sits directly above the source, because the question it answers — "how did
/// we get here?" — is one a reader has while looking at the code, not before
/// opening it. The caller list says who <i>can</i> call this; the chain says
/// how the program actually arrives, from a starting point downwards.
///
/// Ported from Sources/Atlas/UI/CallChainView.swift.
/// </summary>
public sealed class CallChainView : UserControl
{
    public CallChainView(Report report, Strings t, int index, Action<int> select)
    {
        var chain = index >= 0 && index < report.Symbols.Count
            ? report.Symbols[index].Chain : [];
        if (chain.Count <= 1) { IsVisible = false; return; }

        var head = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 9,
            Margin = new Thickness(0, 0, 0, 6),
        };
        head.Children.Add(new TextBlock
        {
            Text = t["callChain"].ToUpperInvariant(),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Label,
            FontWeight = FontWeight.SemiBold,
            LetterSpacing = 1.0,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
        });
        head.Children.Add(new TextBlock
        {
            Text = t["callChainHint"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            VerticalAlignment = VerticalAlignment.Center,
        });

        var links = new StackPanel { Orientation = Orientation.Horizontal };
        for (int i = 0; i < chain.Count; i++)
        {
            if (i > 0)
            {
                // The arrow points the way execution runs, and takes the
                // downstream ink to say so.
                links.Children.Add(new TextBlock
                {
                    Text = "→",
                    FontFamily = Broadsheet.Fonts.Serif,
                    FontSize = Broadsheet.Fonts.Caption,
                    Foreground = Broadsheet.Brush(Broadsheet.Fade(Broadsheet.InkCyan, 0.75)),
                    Margin = new Thickness(7, 0),
                    VerticalAlignment = VerticalAlignment.Center,
                });
            }
            links.Children.Add(Link(report, chain[i], chain[i] == index, select));
        }

        Content = new Border
        {
            Padding = new Thickness(16, 10),
            Background = Broadsheet.Brush(Broadsheet.Surface),
            Child = new StackPanel
            {
                Children =
                {
                    head,
                    new ScrollViewer
                    {
                        HorizontalScrollBarVisibility =
                            Avalonia.Controls.Primitives.ScrollBarVisibility.Hidden,
                        VerticalScrollBarVisibility =
                            Avalonia.Controls.Primitives.ScrollBarVisibility.Disabled,
                        Content = links,
                    },
                },
            },
        };
    }

    private static Control Link(Report report, int index, bool current, Action<int> select)
    {
        var text = new TextBlock
        {
            Text = report.Symbols[index].Display,
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.MonoSmall,
            FontWeight = current ? FontWeight.SemiBold : FontWeight.Normal,
            Foreground = Broadsheet.Brush(current ? Broadsheet.TextPrimary
                                                 : Broadsheet.TextSecondary),
        };
        var button = new Button
        {
            Content = text,
            // The current link is underlined rather than tinted — the same
            // rule the tabs use, for the same reason.
            Background = Broadsheet.Brush(current ? Broadsheet.SurfaceSunken : Colors.Transparent),
            BorderThickness = new Thickness(0, 0, 0, current ? 1.5 : 0),
            BorderBrush = Broadsheet.Brush(Broadsheet.TextPrimary),
            CornerRadius = new CornerRadius(0),
            Padding = new Thickness(8, 4),
        };
        int target = index;
        button.Click += (_, _) => select(target);
        return button;
    }
}
