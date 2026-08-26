using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

public partial class MainWindow : Window
{
    private readonly Panel _root;
    private readonly ContentControl _stage = new();

    private EngineRunner? _engine;
    private Strings _strings = new(new Dictionary<string, string>(), "en");
    private Report? _report;
    private Settings _settings = Settings.Load();
    private string? _complaint;
    private string _screen = "overview";

    public MainWindow()
    {
        InitializeComponent();

        _root = this.FindControl<Panel>("Root")!;
        _root.Children.Add(new PaperBackground());
        _root.Children.Add(_stage);

        Opened += async (_, _) => await StartAsync();
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    /// <summary>
    /// The same shortcuts the macOS build has, under Ctrl rather than Command,
    /// plus Ctrl+1..4 for the tabs — which is what a Windows reader will try
    /// first, and costs nothing to honour.
    /// </summary>
    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (e.Handled) return;

        bool control = e.KeyModifiers.HasFlag(KeyModifiers.Control);
        bool shift = e.KeyModifiers.HasFlag(KeyModifiers.Shift);
        if (!control) return;

        switch (e.Key)
        {
            case Key.O:
                _ = ChooseAsync();
                break;
            case Key.R when _report is not null:
                _ = AnalyzeAsync(_report.Project.Root);
                break;
            case Key.W when shift:
                _report = null;
                _complaint = null;
                ShowWelcome();
                break;
            case Key.D0 when _report is not null:
                ShowProject("overview");
                break;
            case Key.D1 when _report is not null: ShowProject("overview"); break;
            case Key.D2 when _report is not null: ShowProject("map"); break;
            case Key.D3 when _report is not null: ShowProject("read"); break;
            case Key.D4 when _report is not null: ShowProject("review"); break;
            case Key.E when _report is not null:
                Reveal.InFileManager(_report.Project.Root);
                break;
            default:
                return;
        }
        e.Handled = true;
    }

    private async Task StartAsync()
    {
        var located = EngineRunner.Locate();
        if (located is null)
        {
            Show(Message(
                "atlas-engine not found",
                "Atlas does its reading in a separate program. Build it with " +
                "`swift build -c release`, or point ATLAS_ENGINE at a copy."));
            return;
        }

        _engine = new EngineRunner(located);
        try
        {
            _strings = new Strings(await _engine.StringsAsync(_settings.Language),
                                   _settings.Language);
        }
        catch (EngineException error)
        {
            Show(Message("atlas-engine could not be run", error.Message));
            return;
        }
        if (Screenshot.ProjectPath is { } project)
        {
            await AnalyzeAsync(project);
            return;
        }
        ShowWelcome();
    }

    // MARK: - Stages

    /// <param name="settled">
    /// False while something is still in flight. A screenshot run waits for a
    /// settled screen, or it captures the progress line and exits before the
    /// thing it was asked to photograph exists.
    /// </param>
    private void Show(Control content, bool settled = true)
    {
        _stage.Content = content;
        if (settled && Screenshot.Requested)
            Screenshot.CaptureAndExit(_root, new Avalonia.Size(Width, Height));
    }

    private void ShowWelcome() =>
        Show(new WelcomeView(_strings, _settings,
                             open: AnalyzeAsync,
                             chooseFolder: () => _ = ChooseAsync(),
                             setLanguage: SwitchLanguage,
                             complaint: _complaint));

    /// <summary>
    /// Swaps the interface language.
    ///
    /// The strings come from the engine, so this refetches them rather than
    /// holding both tables in memory — and it re-analyses any open project,
    /// because a report carries its own wording: issue titles, drift notes and
    /// explanations were all written in the language it was asked for.
    /// </summary>
    private void SwitchLanguage(string language)
    {
        if (language == _strings.Language || _engine is null) return;
        _settings.Language = language;
        _settings.Save();

        _ = Task.Run(async () =>
        {
            var table = await _engine.StringsAsync(language);
            await Dispatcher.UIThread.InvokeAsync(async () =>
            {
                _strings = new Strings(table, language);
                if (_report is not null) await AnalyzeAsync(_report.Project.Root);
                else ShowWelcome();
            });
        });
    }

    private async Task ChooseAsync()
    {
        var folders = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = _strings["welcomeTitle"],
            AllowMultiple = false,
        });
        if (folders.Count == 0) return;
        await AnalyzeAsync(folders[0].Path.LocalPath);
    }

    private async Task AnalyzeAsync(string path)
    {
        var caption = new TextBlock
        {
            Text = _strings["analyzing"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Title,
            Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        var detail = new TextBlock
        {
            FontFamily = Broadsheet.Fonts.Mono,
            FontSize = Broadsheet.Fonts.MonoSmall,
            Foreground = Broadsheet.Brush(Broadsheet.TextTertiary),
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        var stack = new StackPanel
        {
            Spacing = 10,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        stack.Children.Add(caption);
        stack.Children.Add(detail);
        Show(stack, settled: false);

        // Progress arrives from the engine's parsing threads; hop to the UI
        // thread before touching a control.
        var progress = new Progress<AnalysisProgress>(tick =>
            detail.Text = tick.Total > 0
                ? $"{Stage(tick.Stage)} {tick.Current}/{tick.Total}"
                : Stage(tick.Stage));

        try
        {
            _report = await _engine!.AnalyzeAsync(path, _strings.Language, progress);
            _complaint = null;
            _settings.Remember(Path.GetFullPath(path));
            ShowProject(_screen == "overview" ? Screenshot.Screen : _screen);
        }
        catch (EngineException error)
        {
            // Back to the welcome screen with the reason, rather than a dead
            // end: the next thing the reader wants is another folder.
            _complaint = error.Message;
            _report = null;
            ShowWelcome();
        }
    }

    // MARK: - The project shell

    /// <summary>
    /// The tabs, and whichever view is on. Built fresh per switch rather than
    /// kept alive: each view reads a finished report and holds no state worth
    /// preserving, and the Map refits itself to the window anyway.
    /// </summary>
    private void ShowProject(string screen)
    {
        if (_report is null) return;
        _screen = screen;

        var tabs = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 20,
            Margin = new Avalonia.Thickness(44, 14, 44, 12),
        };
        foreach (var (key, name) in new[]
                 { ("overview", "tabOverview"), ("map", "tabMap"),
                   ("read", "tabRead"), ("review", "tabReview") })
        {
            bool on = key == screen || (key == "map" && screen == "matrix");
            var tab = new Button
            {
                Content = new TextBlock
                {
                    Text = _strings[name].ToUpperInvariant(),
                    FontFamily = Broadsheet.Fonts.Serif,
                    FontSize = Broadsheet.Fonts.Label,
                    FontWeight = FontWeight.SemiBold,
                    LetterSpacing = Broadsheet.Fonts.LabelTracking,
                    // The current tab is the one printed solid — position is
                    // set in ink weight, never a hue.
                    Foreground = Broadsheet.Brush(on ? Broadsheet.TextPrimary
                                                     : Broadsheet.TextTertiary),
                },
                Background = Brushes.Transparent,
                BorderThickness = new Avalonia.Thickness(0, 0, 0, on ? 1.5 : 0),
                BorderBrush = Broadsheet.Brush(Broadsheet.TextPrimary),
                CornerRadius = new Avalonia.CornerRadius(0),
                Padding = new Avalonia.Thickness(0, 0, 0, 5),
            };
            string target = key;
            tab.Click += (_, _) => ShowProject(target);
            tabs.Children.Add(tab);
        }

        // Ladder and Matrix are two drawings of the same dependency data, so
        // they share a tab and switch between themselves.
        if (screen is "map" or "matrix")
        {
            var views = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Spacing = 14,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Avalonia.Thickness(24, 0, 0, 0),
            };
            foreach (var (key, name) in new[] { ("map", "viewLadder"), ("matrix", "viewMatrix") })
            {
                bool on = key == screen;
                var pick = new Button
                {
                    Content = new TextBlock
                    {
                        Text = _strings[name],
                        FontFamily = Broadsheet.Fonts.Serif,
                        FontSize = Broadsheet.Fonts.Caption,
                        Foreground = Broadsheet.Brush(on ? Broadsheet.TextPrimary
                                                         : Broadsheet.TextTertiary),
                    },
                    Background = Brushes.Transparent,
                    BorderThickness = new Avalonia.Thickness(0),
                    Padding = new Avalonia.Thickness(0),
                };
                string target = key;
                pick.Click += (_, _) => ShowProject(target);
                views.Children.Add(pick);
            }
            tabs.Children.Add(views);
        }

        Control body = screen switch
        {
            "map" => new MapView(_report, _strings),
            // The grid is bigger than any window at a useful cell size, so it
            // scrolls rather than zooms.
            "matrix" => MatrixPane(),
            "read" => new ReadView(_report, _strings, _engine!, _settings),
            "review" => new IssuesView(_report, _strings),
            _ => new OverviewView(_report, _strings),
        };

        var shell = new DockPanel();
        DockPanel.SetDock(tabs, Dock.Top);
        shell.Children.Add(tabs);
        shell.Children.Add(body);
        Show(shell);
    }

    /// <summary>
    /// The grid, scrolled rather than zoomed: at a useful cell size it is
    /// bigger than any window, and shrinking it to fit would make the marks
    /// unreadable, which is the one thing the view is for.
    /// </summary>
    private Control MatrixPane()
    {
        var grid = new MatrixView(_report!, _strings);
        var scroller = new ScrollViewer
        {
            HorizontalScrollBarVisibility =
                Avalonia.Controls.Primitives.ScrollBarVisibility.Auto,
            Content = new Border
            {
                Padding = new Avalonia.Thickness(26),
                Child = grid,
            },
        };
        // Applied after layout, not on the spot: a ScrollViewer clamps Offset
        // against an extent it does not have until it has measured, so setting
        // it any earlier silently lands on zero.
        Avalonia.Vector? wanted = null;
        grid.ScrollWanted += area =>
            wanted = new Avalonia.Vector(Math.Max(0, area.X), Math.Max(0, area.Y));
        scroller.LayoutUpdated += (_, _) =>
        {
            if (wanted is not { } target || scroller.Extent.Height <= 0) return;
            wanted = null;
            scroller.Offset = target;
        };
        return scroller;
    }

    private string Stage(string stage) => stage switch
    {
        "scanning"  => _strings["stageScanning"],
        "parsing"   => _strings["stageParsing"],
        "resolving" => _strings["stageResolving"],
        _           => stage,
    };

    private static Control Message(string title, string detail)
    {
        var stack = new StackPanel
        {
            Spacing = 8,
            MaxWidth = 520,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        stack.Children.Add(new TextBlock
        {
            Text = title,
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Title,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
            TextWrapping = TextWrapping.Wrap,
        });
        stack.Children.Add(new TextBlock
        {
            Text = detail,
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Body,
            Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
            TextWrapping = TextWrapping.Wrap,
            LineHeight = 21,
        });
        return stack;
    }
}
