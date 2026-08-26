using System.Globalization;
using System.Text;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Documents;
using Avalonia.Layout;
using Avalonia.Media;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

/// <summary>
/// An ordered way in: the route down the left, the code on the right.
///
/// The route is the engine's — the functions that reach the most of the
/// codebase, in the order they should be read. Ported from RouteRail.swift
/// and SourceView.swift.
/// </summary>
public sealed class ReadView : UserControl
{
    private readonly Report _report;
    private readonly Strings _t;
    private readonly EngineRunner _engine;
    private readonly StackPanel _rail = new() { Spacing = 0 };
    private readonly ContentControl _stage = new();
    private readonly ContentControl _inspector = new();
    private readonly StackPanel _list = new() { Spacing = 0 };
    private readonly Settings _settings;
    private readonly ContentControl _footer = new();

    private int _selected;
    private string _query = "";

    public ReadView(Report report, Strings t, EngineRunner engine,
                    Settings settings, int step = 0)
    {
        _settings = settings;
        _report = report;
        _t = t;
        _engine = engine;
        _selected = Screenshot.Select is { } picked
                    && picked >= 0 && picked < report.Symbols.Count
            ? picked
            : report.Route.Count > 0
                ? report.Route[Math.Clamp(step, 0, report.Route.Count - 1)].Symbol
                : -1;

        var railColumn = new Border
        {
            Width = Broadsheet.Metric.SidebarWidth,
            Padding = new Thickness(20, 22),
            BorderThickness = new Thickness(0, 0, 1, 0),
            BorderBrush = Broadsheet.Brush(Broadsheet.Border),
            Child = new DockPanel
            {
                Children =
                {
                    Footer(),
                    new ScrollViewer { Content = _rail },
                },
            },
        };

        var inspectorColumn = new Border
        {
            Width = Broadsheet.Metric.InspectorWidth,
            BorderThickness = new Thickness(1, 0, 0, 0),
            BorderBrush = Broadsheet.Brush(Broadsheet.Border),
            Child = _inspector,
        };

        var shell = new DockPanel();
        DockPanel.SetDock(railColumn, Dock.Left);
        DockPanel.SetDock(inspectorColumn, Dock.Right);
        shell.Children.Add(railColumn);
        shell.Children.Add(inspectorColumn);
        shell.Children.Add(_stage);
        Content = shell;

        BuildRail();
        _ = ShowAsync(_selected);
    }

    /// <summary>
    /// How much of the route has been read. Docked to the bottom of the rail,
    /// where it is answering "how far in am I" rather than competing with the
    /// list for attention.
    /// </summary>
    private Control Footer()
    {
        DockPanel.SetDock(_footer, Dock.Bottom);
        RefreshFooter();
        return _footer;
    }

    private void RefreshFooter()
    {
        int total = _report.Route.Count;
        if (total == 0) { _footer.Content = null; return; }

        int done = _report.Route.Count(step =>
            _settings.IsUnderstood(_report.Project.Root,
                                   Settings.Signature(_report, step.Symbol)));

        var head = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        var label = new TextBlock
        {
            Text = _t["readingProgress"].ToUpperInvariant(),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            LetterSpacing = 0.7,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
        };
        var count = new TextBlock
        {
            Text = $"{done} / {total}",
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
        };
        Grid.SetColumn(count, 1);
        head.Children.Add(label);
        head.Children.Add(count);

        double share = Math.Clamp((double)done / total, 0, 1);
        var bar = new Grid
        {
            Height = 3,
            Margin = new Thickness(0, 5, 0, 0),
            ColumnDefinitions = new ColumnDefinitions(string.Create(
                System.Globalization.CultureInfo.InvariantCulture,
                $"{share:0.####}*,{1 - share:0.####}*")),
        };
        var track = new Border { Background = Broadsheet.Brush(Broadsheet.Border) };
        Grid.SetColumnSpan(track, 2);
        var fill = new Border { Background = Broadsheet.Brush(Broadsheet.Accent) };
        bar.Children.Add(track);
        bar.Children.Add(fill);

        _footer.Content = new Border
        {
            Padding = new Thickness(0, 12, 0, 0),
            Child = new StackPanel { Children = { head, bar } },
        };
    }

    // MARK: - The rail

    /// <summary>
    /// The search box, built once.
    ///
    /// It used to be rebuilt with the rest of the rail, which recursed without
    /// end: attaching a TextBox raises TextChanged, the handler rebuilt the
    /// rail, and that made another TextBox. Only the list below it changes now.
    /// </summary>
    private void BuildRail()
    {
        _rail.Children.Clear();

        var search = new TextBox
        {
            PlaceholderText = _t["searchPlaceholder"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Caption,
            Margin = new Thickness(0, 0, 0, 14),
            CornerRadius = new CornerRadius(Broadsheet.Metric.Radius),
        };
        search.TextChanged += (_, _) =>
        {
            _query = search.Text ?? "";
            RefreshList();
        };
        _rail.Children.Add(search);
        _rail.Children.Add(_list);

        if (Screenshot.Query is { Length: > 0 } typed) search.Text = typed;
        RefreshList();
    }

    /// <summary>
    /// Matches while there is a query, the route otherwise.
    ///
    /// The route is an argument about where to start; a search is the reader
    /// already knowing. They should not compete for the same column.
    /// </summary>
    private void RefreshList()
    {
        _list.Children.Clear();

        if (_query.Length > 0)
        {
            var hits = Search.Find(_report, _query);
            if (hits.Count == 0)
            {
                _list.Children.Add(Note(_t["noResults"]));
                return;
            }
            foreach (int index in hits.Take(40)) _list.Children.Add(Hit(index));
            return;
        }

        _list.Children.Add(new Rule(_t["routeLabel"]));
        if (_report.Route.Count == 0)
        {
            _list.Children.Add(Note(_t["routeEmpty"]));
            return;
        }
        _list.Children.Add(new TextBlock
        {
            Text = _t["routeHint"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Micro,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            TextWrapping = TextWrapping.Wrap,
            LineHeight = 15,
            Margin = new Thickness(0, 8, 0, 12),
        });
        for (int i = 0; i < _report.Route.Count; i++) _list.Children.Add(RailStep(i));

        // The hubs the route does not pass through. A reader who has finished
        // the route still wants to know what else the codebase leans on.
        var onRoute = _report.Route.Select(step => step.Symbol).ToHashSet();
        var others = _report.Hubs.Where(h => !onRoute.Contains(h)).Take(8).ToList();
        if (others.Count == 0) return;

        _list.Children.Add(new Border
        {
            Margin = new Thickness(0, 18, 0, 6),
            Child = new Rule(_t["everythingElse"]),
        });
        foreach (int id in others) _list.Children.Add(Hit(id));
    }

    private Control Hit(int index)
    {
        var name = new TextBlock
        {
            Text = _report.Symbols[index].Display,
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.MonoSmall,
            Foreground = Broadsheet.Brush(index == _selected
                ? Broadsheet.TextPrimary : Broadsheet.TextSecondary),
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        var button = new Button
        {
            Content = name,
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(0),
            CornerRadius = new CornerRadius(0),
            Padding = new Thickness(2, 6),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Left,
        };
        int target = index;
        button.Click += (_, _) => { _selected = target; RefreshList(); _ = ShowAsync(target); };
        return button;
    }

    private static TextBlock Note(string text) => new()
    {
        Text = text,
        FontFamily = Broadsheet.Fonts.Serif,
        FontSize = Broadsheet.Fonts.Caption,
        Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
        TextWrapping = TextWrapping.Wrap,
        Margin = new Thickness(0, 8, 0, 0),
    };

    private Control RailStep(int index)
    {
        var symbol = _report.Symbols[_report.Route[index].Symbol];
        bool current = _report.Route[index].Symbol == _selected;

        // Position is set in weight, not a hue: both process inks already mean
        // a direction and a third colour would start competing with them.
        bool read = _settings.IsUnderstood(
            _report.Project.Root, Settings.Signature(_report, _report.Route[index].Symbol));

        var ordinal = new TextBlock
        {
            // A read step shows a tick where its number was.
            Text = read ? "✓" : (index + 1).ToString(CultureInfo.InvariantCulture),
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Caption,
            FontWeight = current ? FontWeight.Bold : FontWeight.Normal,
            Foreground = Broadsheet.Brush(read ? Broadsheet.Accent
                                              : current ? Broadsheet.Marker
                                                        : Broadsheet.TextTertiary),
            Width = 18,
            VerticalAlignment = VerticalAlignment.Center,
        };
        var name = new TextBlock
        {
            Text = symbol.Display,
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.MonoSmall,
            FontWeight = current ? FontWeight.Medium : FontWeight.Normal,
            Foreground = Broadsheet.Brush(current ? Broadsheet.TextPrimary : Broadsheet.TextSecondary),
            TextTrimming = TextTrimming.CharacterEllipsis,
            VerticalAlignment = VerticalAlignment.Center,
        };

        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("18,*") };
        Grid.SetColumn(ordinal, 0);
        Grid.SetColumn(name, 1);
        row.Children.Add(ordinal);
        row.Children.Add(name);

        var button = new Button
        {
            Content = row,
            Background = Broadsheet.Brush(current ? Broadsheet.SurfaceRaised : Colors.Transparent),
            BorderThickness = new Thickness(current ? 2 : 0, 0, 0, 0),
            BorderBrush = Broadsheet.Brush(Broadsheet.Marker),
            CornerRadius = new CornerRadius(0),
            Padding = new Thickness(current ? 8 : 10, 7),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Left,
        };
        int target = index;
        button.Click += (_, _) =>
        {
            _selected = _report.Route[target].Symbol;
            RefreshList();
            _ = ShowAsync(_selected);
        };
        return button;
    }

    // MARK: - The code

    private async Task ShowAsync(int index)
    {
        if (index < 0 || index >= _report.Symbols.Count)
        {
            _stage.Content = Message(_t["pickSomething"]);
            _inspector.Content = new InspectorView(_report, _t, -1, null);
            return;
        }

        var symbol = _report.Symbols[index];
        if (symbol.File < 0 || symbol.File >= _report.Files.Count)
        {
            _stage.Content = Message(_t["pickSomething"]);
            return;
        }

        var file = _report.Files[symbol.File];
        _stage.Content = Message(_t["thinking"]);
        try
        {
            var snippet = await _engine.SourceAsync(
                _report.Project.Root, file.Path, symbol.Line, symbol.EndLine);
            _stage.Content = Code(index, symbol, file, snippet);
            _inspector.Content = new InspectorView(
                _report, _t, index, snippet, _settings,
                onToggleRead: () => { RefreshList(); RefreshFooter(); _ = ShowAsync(index); });
        }
        catch (EngineException error)
        {
            _stage.Content = Message(error.Message);
        }
    }

    private Control Code(int index, SymbolEntry symbol, FileEntry file, SourceSnippet snippet)
    {
        var header = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
            Margin = new Thickness(16, 12),
        };
        header.Children.Add(new TextBlock
        {
            Text = symbol.Display,
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.MonoSize,
            FontWeight = FontWeight.Medium,
            Foreground = Broadsheet.Brush(Broadsheet.ForKind(symbol.Kind, symbol.External)),
        });
        var where = new Button
        {
            Content = new TextBlock
            {
                Text = $"{file.Path}:{symbol.Line}",
                FontFamily = Broadsheet.Fonts.Serif,
                FontSize = Broadsheet.Fonts.Micro,
                Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
                TextTrimming = TextTrimming.CharacterEllipsis,
            },
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(0),
            CornerRadius = new CornerRadius(0),
            Padding = new Thickness(0),
            VerticalAlignment = VerticalAlignment.Center,
        };
        // Atlas reads code; it does not edit it. Naming a file without being
        // able to open it just moves the search back to the reader.
        where.Click += (_, _) => Reveal.InEditor(
            Path.Combine(_report.Project.Root, file.Path.Replace('/', Path.DirectorySeparatorChar)));
        header.Children.Add(where);

        var gutter = new StackPanel { Margin = new Thickness(12, 10, 10, 10) };
        var code = new StackPanel { Margin = new Thickness(0, 10, 20, 10) };
        foreach (var (number, line) in Lines(snippet))
        {
            gutter.Children.Add(new TextBlock
            {
                Text = number.ToString(CultureInfo.InvariantCulture),
                FontFamily = Broadsheet.Fonts.Mono,
                FontSize = Broadsheet.Fonts.MonoSmall,
                Foreground = Broadsheet.Brush(Broadsheet.CodeGutter),
                Height = 17,
                TextAlignment = TextAlignment.Right,
            });
            code.Children.Add(line);
        }

        var body = new StackPanel { Orientation = Orientation.Horizontal };
        body.Children.Add(gutter);
        body.Children.Add(code);

        // The neighbourhood sits under the code: who calls this, what it calls.
        var tree = new Border
        {
            // No fixed height: the view measures itself from how many
            // neighbours it has, and a fixed one clipped the last of them.
            BorderThickness = new Thickness(0, 1, 0, 0),
            BorderBrush = Broadsheet.Brush(Broadsheet.Border),
            Child = new CallTreeView(_report, _t, _selected),
        };

        // "How did we get here?" belongs beside the code, not before it.
        var chain = new Border
        {
            BorderThickness = new Thickness(0, 0, 0, 1),
            BorderBrush = Broadsheet.Brush(Broadsheet.Border),
            Child = new CallChainView(_report, _t, index,
                                      pick => { _selected = pick; RefreshList(); _ = ShowAsync(pick); }),
        };

        var shell = new DockPanel();
        var top = new Border
        {
            Child = header,
            BorderThickness = new Thickness(0, 0, 0, 1),
            BorderBrush = Broadsheet.Brush(Broadsheet.Border),
        };
        DockPanel.SetDock(top, Dock.Top);
        DockPanel.SetDock(chain, Dock.Top);
        DockPanel.SetDock(tree, Dock.Bottom);
        shell.Children.Add(top);
        shell.Children.Add(chain);
        shell.Children.Add(tree);
        shell.Children.Add(new ScrollViewer
        {
            HorizontalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Auto,
            Background = Broadsheet.Brush(Broadsheet.CodeBackground),
            Content = body,
        });
        return shell;
    }

    /// <summary>
    /// Rebuilds the snippet a line at a time, colouring each run.
    ///
    /// Span offsets are UTF-8 byte positions, so the text is walked as bytes;
    /// indexing the string by them would land mid-character on anything
    /// outside ASCII. A run that straddles a newline is split, because each
    /// line is its own TextBlock.
    /// </summary>
    private static IEnumerable<(int Number, TextBlock Line)> Lines(SourceSnippet snippet)
    {
        var bytes = Encoding.UTF8.GetBytes(snippet.Text);
        int number = snippet.FirstLine;
        var current = new TextBlock
        {
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.MonoSize,
            Height = 17,
        };

        foreach (var span in snippet.Spans)
        {
            int end = Math.Min(span.Offset + span.Length, bytes.Length);
            int at = span.Offset;
            while (at < end)
            {
                int newline = Array.IndexOf(bytes, (byte)'\n', at, end - at);
                int stop = newline < 0 ? end : newline;
                if (stop > at)
                {
                    current.Inlines ??= [];
                    current.Inlines.Add(new Run(Encoding.UTF8.GetString(bytes, at, stop - at))
                    {
                        Foreground = Broadsheet.Brush(Ink(span.Role)),
                        FontStyle = span.Role == "comment" ? FontStyle.Italic : FontStyle.Normal,
                    });
                }
                if (newline < 0) break;

                yield return (number++, current);
                current = new TextBlock
                {
                    FontFamily = Broadsheet.Fonts.Mono,
                    FontSize = Broadsheet.Fonts.MonoSize,
                    Height = 17,
                };
                at = newline + 1;
            }
        }
        yield return (number, current);
    }

    private static Color Ink(string role) => role switch
    {
        "comment"  => Broadsheet.CodeComment,
        "string"   => Broadsheet.CodeString,
        "number"   => Broadsheet.CodeNumber,
        "keyword"  => Broadsheet.CodeKeyword,
        "function" => Broadsheet.CodeFunction,
        "type"     => Broadsheet.CodeType,
        "punct"    => Broadsheet.CodePunct,
        _          => Broadsheet.CodePlain,
    };

    private static Control Message(string text) => new TextBlock
    {
        Text = text,
        FontFamily = Broadsheet.Fonts.Serif,
        FontSize = Broadsheet.Fonts.Body,
        Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
        TextWrapping = TextWrapping.Wrap,
        MaxWidth = 420,
        HorizontalAlignment = HorizontalAlignment.Center,
        VerticalAlignment = VerticalAlignment.Center,
    };
}
