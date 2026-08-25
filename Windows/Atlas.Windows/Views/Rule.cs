using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;

namespace Atlas.Windows.Views;

/// <summary>
/// A section head set as a printed rule: small caps, widely tracked, then a
/// hairline running to the margin. Ported from OverviewView.swift.
/// </summary>
public sealed class Rule : UserControl
{
    public Rule(string title)
    {
        var label = new TextBlock
        {
            Text = title.ToUpperInvariant(),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Label,
            FontWeight = FontWeight.SemiBold,
            // Tracking is what makes this read as a rule rather than a heading.
            LetterSpacing = Broadsheet.Fonts.LabelTracking,
            Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
            VerticalAlignment = VerticalAlignment.Center,
        };

        var hairline = new Border
        {
            Height = 1,
            Background = Broadsheet.Brush(Broadsheet.Border),
            VerticalAlignment = VerticalAlignment.Center,
        };

        var row = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("Auto,11,*"),
        };
        Grid.SetColumn(label, 0);
        Grid.SetColumn(hairline, 2);
        row.Children.Add(label);
        row.Children.Add(hairline);

        Content = row;
    }
}
