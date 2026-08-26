using System.Text.Json;
using System.Text.Json.Serialization;

namespace Atlas.Windows.Engine;

/// <summary>
/// The handful of things Atlas remembers between runs.
///
/// Kept beside the engine's own state — %LOCALAPPDATA%\Atlas on Windows,
/// Application Support on macOS — so a user clearing one clears both. Nothing
/// here is worth failing a launch over: a corrupt or missing file simply means
/// defaults.
/// </summary>
public sealed record Settings
{
    [JsonPropertyName("language")] public string Language { get; set; } = "en";
    [JsonPropertyName("recents")]  public List<string> Recents { get; set; } = [];

    private const int MaxRecents = 8;

    private static string Directory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Atlas");

    private static string File => Path.Combine(Directory, "client.json");

    public static Settings Load()
    {
        try
        {
            if (System.IO.File.Exists(File))
            {
                var text = System.IO.File.ReadAllText(File);
                return JsonSerializer.Deserialize(text, ReportContext.Default.Settings)
                       ?? new Settings();
            }
        }
        catch (Exception error) when (error is IOException or JsonException
                                           or UnauthorizedAccessException)
        {
            // Unreadable settings are not worth a dialog; start fresh.
        }
        return new Settings();
    }

    public void Save()
    {
        try
        {
            System.IO.Directory.CreateDirectory(Directory);
            System.IO.File.WriteAllText(File,
                JsonSerializer.Serialize(this, ReportContext.Default.Settings));
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            // Losing the recents list is a smaller problem than refusing to run.
        }
    }

    /// <summary>Moves a project to the front, dropping the oldest beyond the cap.</summary>
    public void Remember(string path)
    {
        Recents.RemoveAll(p => string.Equals(p, path, StringComparison.OrdinalIgnoreCase));
        Recents.Insert(0, path);
        if (Recents.Count > MaxRecents) Recents.RemoveRange(MaxRecents, Recents.Count - MaxRecents);
        Save();
    }

    /// <summary>Recents that still exist, so a moved folder does not linger.</summary>
    public IEnumerable<string> LiveRecents() =>
        Recents.Where(System.IO.Directory.Exists);
}
