using System.Globalization;

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
    /// A string that takes a value, with <c>{0}</c> filled in.
    ///
    /// The templates come from the engine complete, word order included:
    /// English puts the number after the verb, Uzbek before it, so composing
    /// the sentence here would get one of the two languages wrong.
    /// </summary>
    public string Format(string key, object value) =>
        this[key].Replace("{0}", Convert.ToString(value, CultureInfo.CurrentCulture));

    /// <summary>The two-value form, for strings like "{0} files reach it · it reaches {1}".</summary>
    public string Format(string key, object first, object second) =>
        this[key].Replace("{0}", Convert.ToString(first, CultureInfo.CurrentCulture))
                 .Replace("{1}", Convert.ToString(second, CultureInfo.CurrentCulture));

    /// <summary>
    /// Large counts, abbreviated. Mirrors L10n.count(_:) exactly.
    ///
    /// Formatted against the invariant culture, not the machine's. Swift's
    /// String(format:) writes the C locale's decimal point, so a reader whose
    /// region uses a comma would see "9,7k" here and "9.7k" in the same
    /// project on macOS — the same number, printed two ways, in an app whose
    /// whole point is that the two builds agree.
    /// </summary>
    public static string Count(int n) => n switch
    {
        >= 1_000_000 => FormattableString.Invariant($"{n / 1_000_000.0:0.0}M"),
        >= 10_000    => FormattableString.Invariant($"{n / 1_000.0:0}k"),
        >= 1_000     => FormattableString.Invariant($"{n / 1_000.0:0.0}k"),
        _            => n.ToString(CultureInfo.InvariantCulture),
    };

    /// <summary>Mirrors L10n.seconds(_:), invariant for the same reason.</summary>
    public static string Seconds(double v) =>
        v < 1 ? FormattableString.Invariant($"{v * 1000:0} ms")
              : FormattableString.Invariant($"{v:0.00} s");
}
