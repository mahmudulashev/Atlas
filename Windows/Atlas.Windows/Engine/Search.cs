namespace Atlas.Windows.Engine;

/// <summary>
/// Finding a declaration by name.
///
/// A query over the symbols the report already carries, so it runs here rather
/// than in the engine — but the <b>order</b> is copied exactly from
/// AppState.searchResults, ties included. An exact match first, then a prefix
/// match, then the most-called; and when two are equally called, the earlier
/// index. Swift's sort is not stable and OrderBy is, so without that last rule
/// the two builds of Atlas would list the same matches differently.
/// </summary>
public static class Search
{
    public static IReadOnlyList<int> Find(Report report, string query)
    {
        if (string.IsNullOrWhiteSpace(query)) return [];
        string needle = query.ToLowerInvariant();

        var hits = new List<int>();
        for (int i = 0; i < report.Symbols.Count; i++)
        {
            var symbol = report.Symbols[i];
            if (symbol.Name.ToLowerInvariant().Contains(needle, StringComparison.Ordinal)
                || (symbol.Container?.ToLowerInvariant().Contains(needle, StringComparison.Ordinal) ?? false))
            {
                hits.Add(i);
            }
        }

        hits.Sort((a, b) =>
        {
            var na = report.Symbols[a].Name.ToLowerInvariant();
            var nb = report.Symbols[b].Name.ToLowerInvariant();

            bool exactA = na == needle, exactB = nb == needle;
            if (exactA != exactB) return exactA ? -1 : 1;

            bool prefixA = na.StartsWith(needle, StringComparison.Ordinal);
            bool prefixB = nb.StartsWith(needle, StringComparison.Ordinal);
            if (prefixA != prefixB) return prefixA ? -1 : 1;

            int fanIn = report.Symbols[b].FanIn.CompareTo(report.Symbols[a].FanIn);
            return fanIn != 0 ? fanIn : a.CompareTo(b);
        });
        return hits;
    }
}
