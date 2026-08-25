namespace Atlas.Windows.Engine;

/// <summary>
/// The interface strings, looked up by the same keys the Swift side uses.
///
/// A missing key returns the key itself rather than throwing or rendering
/// blank: a screen with <c>startHereHint</c> printed on it says exactly what
/// is wrong, where an empty gap says nothing.
/// </summary>
public sealed class Strings(IReadOnlyDictionary<string, string> table, string language)
{
    public string Language { get; } = language;

    public string this[string key] =>
        table.TryGetValue(key, out var value) ? value : key;

    /// <summary>
    /// Large counts, abbreviated. Mirrors L10n.count(_:) exactly — a figure
    /// that reads "12.3k" on macOS must not read "12,340" on Windows.
    /// </summary>
    public static string Count(int n) => n switch
    {
        >= 1_000_000 => $"{n / 1_000_000.0:0.0}M",
        >= 10_000    => $"{n / 1_000.0:0}k",
        >= 1_000     => $"{n / 1_000.0:0.0}k",
        _            => n.ToString(),
    };

    /// <summary>Mirrors L10n.seconds(_:).</summary>
    public static string Seconds(double v) =>
        v < 1 ? $"{v * 1000:0} ms" : $"{v:0.00} s";
}
