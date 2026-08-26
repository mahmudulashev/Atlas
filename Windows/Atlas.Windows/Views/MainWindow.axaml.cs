using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using Atlas.Windows.Engine;

namespace Atlas.Windows.Views;

public partial class MainWindow : Window
{
    private readonly Panel _root;
    private readonly ContentControl _stage = new();

    private EngineRunner? _engine;
    private Strings _strings = new(new Dictionary<string, string>(), "en");
    private Report? _report;

    public MainWindow()
    {
        InitializeComponent();

        _root = this.FindControl<Panel>("Root")!;
        _root.Children.Add(new PaperBackground());
        _root.Children.Add(_stage);

        Opened += async (_, _) => await StartAsync();
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

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
            _strings = new Strings(await _engine.StringsAsync(), "en");
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

    private void ShowWelcome()
    {
        var title = new TextBlock
        {
            Text = _strings["welcomeTitle"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Display,
            FontWeight = FontWeight.SemiBold,
            Foreground = Broadsheet.Brush(Broadsheet.TextPrimary),
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        var body = new TextBlock
        {
            Text = _strings["welcomeBody"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Body,
            Foreground = Broadsheet.Brush(Broadsheet.TextSecondary),
            TextWrapping = TextWrapping.Wrap,
            TextAlignment = TextAlignment.Center,
            MaxWidth = 460,
            LineHeight = 21,
        };
        var choose = new Button
        {
            Content = _strings["chooseFolder"],
            FontFamily = Broadsheet.Fonts.Serif,
            FontSize = Broadsheet.Fonts.Body,
            HorizontalAlignment = HorizontalAlignment.Center,
            Padding = new Avalonia.Thickness(18, 8),
        };
        choose.Click += async (_, _) => await ChooseAsync();

        var stack = new StackPanel
        {
            Spacing = 18,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        stack.Children.Add(title);
        stack.Children.Add(body);
        stack.Children.Add(choose);
        Show(stack);
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
            ShowProject(Screenshot.Screen);
        }
        catch (EngineException error)
        {
            Show(Message(_strings["noSourceFiles"], error.Message));
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

        var tabs = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 20,
            Margin = new Avalonia.Thickness(44, 14, 44, 12),
        };
        foreach (var (key, name) in new[] { ("overview", "tabOverview"), ("map", "tabMap") })
        {
            bool on = key == screen;
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

        Control body = screen == "map"
            ? new LadderView(_report, _strings)
            : new OverviewView(_report, _strings);

        var shell = new DockPanel();
        DockPanel.SetDock(tabs, Dock.Top);
        shell.Children.Add(tabs);
        shell.Children.Add(body);
        Show(shell);
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
