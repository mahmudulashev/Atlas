using System.Diagnostics;

namespace Atlas.Windows.Engine;

/// <summary>
/// Handing a file back to the desktop.
///
/// Atlas reads code; it does not edit it. Every view that names a file should
/// be able to open the real thing, or the reader has to go and find it by
/// hand — which is the friction the app exists to remove.
/// </summary>
public static class Reveal
{
    /// <summary>Shows the file in the file manager, selected where possible.</summary>
    public static void InFileManager(string path)
    {
        if (!File.Exists(path) && !Directory.Exists(path)) return;
        try
        {
            if (OperatingSystem.IsWindows())
            {
                // The comma is not a typo: /select, takes the path as one
                // argument and explorer is particular about the spelling.
                Run("explorer.exe", $"/select,\"{path}\"");
            }
            else if (OperatingSystem.IsMacOS())
            {
                Run("open", $"-R \"{path}\"");
            }
            else
            {
                Run("xdg-open", $"\"{Path.GetDirectoryName(path)}\"");
            }
        }
        catch (Exception error) when (error is IOException or InvalidOperationException
                                           or System.ComponentModel.Win32Exception)
        {
            // No file manager is not a reason to take the app down.
        }
    }

    /// <summary>Opens the file with whatever the desktop thinks owns it.</summary>
    public static void InEditor(string path)
    {
        if (!File.Exists(path)) return;
        try
        {
            Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
        }
        catch (Exception error) when (error is IOException or InvalidOperationException
                                           or System.ComponentModel.Win32Exception)
        {
        }
    }

    private static void Run(string program, string arguments) =>
        Process.Start(new ProcessStartInfo(program, arguments) { UseShellExecute = false });
}
