using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

/// <summary>
/// First run, and the state after closing a project.
/// Ported from Sources/Atlas/UI/WelcomeView.swift.
/// </summary>
public sealed class WelcomeView : UserControl
{
    private readonly Border _dropZone;
    private bool _targeted;

    public WelcomeView(Strings t, Settings settings,
                       Func<string, Task> open,
                       Action chooseFolder,
                       Action<string> setLanguage,
                       string? complaint)
    {
        var column = new StackPanel
        {
            Spacing = 0,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            MaxWidth = 520,
        };

        column.Children.Add(new MarkGlyph(76)
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 18),
        });
        column.Children.Add(Centred("Atlas", Broadsheet.Fonts.Display,
                                    Broadsheet.TextPrimary, FontWeight.SemiBold));
        column.Children.Add(Centred(t["appTagline"], Broadsheet.Fonts.Body,
                                    Broadsheet.TextSecondary));

        _dropZone = DropZone(t, chooseFolder);
        column.Children.Add(_dropZone);

        // errorMessage used to be set and never read: dropping a folder with
        // nothing recognisable in it returned here in silence, which reads as
        // the app having ignored the gesture.
        if (complaint is { Length: > 0 })
        {
            var row = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Spacing = 8,
                Margin = new Thickness(0, 14, 0, 0),
                HorizontalAlignment = HorizontalAlignment.Center,
            };
            row.Children.Add(new Border
            {
                Width = 2, Height = 30,
                Background = Broadsheet.Brush(Broadsheet.InkMagenta),
            });
            row.Children.Add(new TextBlock
            {
                Text = complaint,
                FontFamily = Broadsheet.Fonts.Serif,
                FontSize = Broadsheet.Fonts.Caption,
                Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
                TextWrapping = TextWrapping.Wrap,
                MaxWidth = 400,
                VerticalAlignment = VerticalAlignment.Center,
            });
            column.Children.Add(row);
        }

        column.Children.Add(new TextBlock
        {
            Text = t["welcomeBody"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Caption,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            TextAlignment = TextAlignment.Center,
            TextWrapping = TextWrapping.Wrap,
            LineHeight = 18,
            MaxWidth = 420,
            Margin = new Thickness(0, 16, 0, 0),
            HorizontalAlignment = HorizontalAlignment.Center,
        });

        var recents = settings.LiveRecents().Take(5).ToList();
        if (recents.Count > 0) column.Children.Add(Recents(recents, t, open));

        // The language switch sits on the welcome screen because it is the one
        // place a reader is not yet mid-task.
        var languages = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 14,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 30, 0, 0),
        };
        foreach (var (code, label) in new[] { ("en", "English"), ("uz", "O‘zbekcha") })
        {
            bool on = code == t.Language;
            var pick = new Button
            {
                Content = new TextBlock
                {
                    Text = label,
                    FontFamily = Broadsheet.Fonts.Serif,
                    FontSize = Broadsheet.Fonts.Caption,
                    Foreground = Broadsheet.Brush(on ? Broadsheet.TextPrimary
                                                     : Broadsheet.TextTertiary),
                },
                Background = Brushes.Transparent,
                BorderThickness = new Thickness(0, 0, 0, on ? 1 : 0),
                BorderBrush = Broadsheet.Brush(Broadsheet.TextPrimary),
                CornerRadius = new CornerRadius(0),
                Padding = new Thickness(0, 0, 0, 3),
            };
            string target = code;
            pick.Click += (_, _) => setLanguage(target);
            languages.Children.Add(pick);
        }
        column.Children.Add(languages);

        Content = new Panel { Children = { new PaperBackground(), column } };

        // A folder dragged onto the window is the shortest path in.
        AddHandler(DragDrop.DragOverEvent, (_, e) =>
        {
            bool carriesFiles = e.DataTransfer.Contains(DataFormat.File);
            e.DragEffects = carriesFiles ? DragDropEffects.Copy : DragDropEffects.None;
            Target(carriesFiles);
        });
        AddHandler(DragDrop.DragLeaveEvent, (_, _) => Target(false));
        AddHandler(DragDrop.DropEvent, async (_, e) =>
        {
            Target(false);
            var dropped = e.DataTransfer.TryGetFile();
            if (dropped?.Path.LocalPath is { Length: > 0 } path) await open(path);
        });
        DragDrop.SetAllowDrop(this, true);
    }

    private void Target(bool on)
    {
        if (_targeted == on) return;
        _targeted = on;
        _dropZone.BorderBrush = Broadsheet.Brush(on ? Broadsheet.Accent : Broadsheet.Border);
        _dropZone.Background = Broadsheet.Brush(on ? Broadsheet.AccentMuted
                                                  : Broadsheet.SurfaceRaised);
    }

    private static Border DropZone(Strings t, Action chooseFolder)
    {
        var choose = new Button
        {
            Content = new TextBlock
            {
                Text = t["chooseFolder"],
                FontFamily = Broadsheet.Fonts.Serif,
                FontSize = Broadsheet.Fonts.Body,
                FontWeight = FontWeight.Medium,
            },
            HorizontalAlignment = HorizontalAlignment.Center,
            Padding = new Thickness(18, 8),
            CornerRadius = new CornerRadius(Broadsheet.Metric.Radius),
        };
        choose.Click += (_, _) => chooseFolder();

        var inside = new StackPanel { Spacing = 14, HorizontalAlignment = HorizontalAlignment.Center };
        inside.Children.Add(Centred(t["welcomeTitle"], Broadsheet.Fonts.Heading,
                                    Broadsheet.TextPrimary, FontWeight.SemiBold));
        inside.Children.Add(choose);

        return new Border
        {
            // Dashes say "put something here" without a word of instruction.
            BorderThickness = new Thickness(1.4),
            BorderBrush = Broadsheet.Brush(Broadsheet.Border),
            Background = Broadsheet.Brush(Broadsheet.SurfaceRaised),
            CornerRadius = new CornerRadius(Broadsheet.Metric.RadiusLarge),
            Padding = new Thickness(40, 36),
            Margin = new Thickness(0, 30, 0, 0),
            MinWidth = 400,
            Child = inside,
        };
    }

    private static Control Recents(List<string> paths, Strings t, Func<string, Task> open)
    {
        var stack = new StackPanel { Spacing = 2, Margin = new Thickness(0, 30, 0, 0) };
        stack.Children.Add(new TextBlock
        {
            Text = t["recentProjects"].ToUpperInvariant(),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Label,
            FontWeight = FontWeight.SemiBold,
            LetterSpacing = Broadsheet.Fonts.LabelTracking,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            Margin = new Thickness(2, 0, 0, 6),
        });

        foreach (var path in paths)
        {
            var name = new TextBlock
            {
                Text = Path.GetFileName(path.TrimEnd(Path.DirectorySeparatorChar,
                                                     Path.AltDirectorySeparatorChar)),
                FontFamily = Broadsheet.Fonts.Serif,
                FontSize = Broadsheet.Fonts.Caption,
                Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
            };
            var button = new Button
            {
                Content = name,
                Background = Brushes.Transparent,
                BorderThickness = new Thickness(0),
                CornerRadius = new CornerRadius(0),
                Padding = new Thickness(2, 4),
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Left,
            };
            string target = path;
            button.Click += async (_, _) => await open(target);
            stack.Children.Add(button);
        }
        return stack;
    }

    private static TextBlock Centred(string text, double size, Color ink,
                                     FontWeight weight = FontWeight.Normal) => new()
    {
        Text = text,
        FontFamily = Broadsheet.Fonts.Serif,
        FontSize = size,
        FontWeight = weight,
        Foreground = Broadsheet.Brush(ink),
        TextAlignment = TextAlignment.Center,
        TextWrapping = TextWrapping.Wrap,
        HorizontalAlignment = HorizontalAlignment.Center,
    };
}
