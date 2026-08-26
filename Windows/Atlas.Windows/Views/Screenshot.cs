using Avalonia;
using Avalonia.Media.Imaging;
using Avalonia.Threading;

namespace Atlas.Windows.Views;

/// <summary>
/// Renders the window to a PNG and quits.
///
/// A developer affordance, not a feature. Porting a design across toolkits is
/// a visual job, and "it compiled" says nothing about whether the figures line
/// up or the rule sits on the baseline. This makes looking at a screen
/// repeatable — and it works the same on a machine with no display permission
/// to grant, because Avalonia is drawing the pixels either way.
///
///     dotnet run -- --shot out.png --project ../.. --screen map
/// </summary>
public static class Screenshot
{
    public static string? OutputPath { get; private set; }
    public static string? ProjectPath { get; private set; }
    /// <summary>Which screen to photograph: "overview" (default) or "map".</summary>
    public static string Screen { get; private set; } = "overview";
    /// <summary>A map node to select, so the highlight can be photographed.</summary>
    public static int? Select { get; private set; }
    public static bool Requested => OutputPath is not null;

    /// <summary>Pulls the developer flags out, returning the rest.</summary>
    public static string[] Parse(string[] args)
    {
        var rest = new List<string>();
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--shot" when i + 1 < args.Length:
                    OutputPath = args[++i];
                    break;
                case "--project" when i + 1 < args.Length:
                    ProjectPath = args[++i];
                    break;
                case "--screen" when i + 1 < args.Length:
                    Screen = args[++i];
                    break;
                case "--select" when i + 1 < args.Length
                                     && int.TryParse(args[i + 1], out int node):
                    Select = node;
                    i++;
                    break;
                default:
                    rest.Add(args[i]);
                    break;
            }
        }
        return [.. rest];
    }

    /// <summary>
    /// Waits for layout to settle, then writes the file.
    ///
    /// The post at <see cref="DispatcherPriority.Background"/> matters: called
    /// straight after content is set, the visual tree has been built but not
    /// yet measured, and the capture comes out empty.
    /// </summary>
    public static void CaptureAndExit(Visual visual, Size size)
    {
        Dispatcher.UIThread.Post(() =>
        {
            var pixels = new PixelSize(
                Math.Max(1, (int)size.Width), Math.Max(1, (int)size.Height));
            using var bitmap = new RenderTargetBitmap(pixels, new Vector(96, 96));
            bitmap.Render(visual);
            bitmap.Save(OutputPath!, new PngBitmapEncoderOptions());
            Console.WriteLine($"wrote {OutputPath} ({pixels.Width}x{pixels.Height})");
            Environment.Exit(0);
        }, DispatcherPriority.Background);
    }
}
