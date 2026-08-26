using System.Text.RegularExpressions;
using Avalonia.Controls;
using Avalonia.Controls.Documents;
using Avalonia.Media;

namespace Atlas.Windows.Views;

/// <summary>
/// Text with the small amount of markdown the engine actually writes.
///
/// Explanations arrive with names in backticks — "`finishAnalysis` is a
/// method" — and rendered as plain text those backticks are just punctuation
/// on screen. Only the inline subset is handled, because only the inline
/// subset is ever sent.
///
/// Ported from RichText in Sources/Atlas/UI/Components.swift.
/// </summary>
public static partial class RichText
{
    [GeneratedRegex(@"`([^`]+)`|\*\*([^*]+)\*\*|\*([^*]+)\*")]
    private static partial Regex Markup();

    public static TextBlock Block(string raw, double size, Color ink,
                                  double lineHeight = 18, double? maxWidth = null)
    {
        var block = new TextBlock
        {
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = size,
            Foreground = Broadsheet.Brush(ink),
            TextWrapping = TextWrapping.Wrap,
            LineHeight = lineHeight,
            Inlines = [],
        };
        if (maxWidth is { } width) block.MaxWidth = width;

        int at = 0;
        foreach (Match match in Markup().Matches(raw))
        {
            if (match.Index > at)
            {
                block.Inlines.Add(new Run(raw[at..match.Index]));
            }

            if (match.Groups[1].Success)
            {
                // A name from the code, set in the code's own face.
                block.Inlines.Add(new Run(match.Groups[1].Value)
                {
                    FontFamily = Broadsheet.Fonts.Mono,
                    FontSize = size - 1,
                    Foreground = Broadsheet.Brush(Broadsheet.CodeFunction),
                });
            }
            else if (match.Groups[2].Success)
            {
                block.Inlines.Add(new Run(match.Groups[2].Value)
                {
                    FontWeight = FontWeight.SemiBold,
                    Foreground = Broadsheet.Brush(Broadsheet.Accent),
                });
            }
            else
            {
                block.Inlines.Add(new Run(match.Groups[3].Value)
                {
                    FontStyle = FontStyle.Italic,
                });
            }
            at = match.Index + match.Length;
        }
        if (at < raw.Length) block.Inlines.Add(new Run(raw[at..]));
        return block;
    }
}
