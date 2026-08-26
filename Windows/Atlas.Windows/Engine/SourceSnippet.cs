using System.Text.Json.Serialization;

namespace Atlas.Windows.Engine;

/// <summary>
/// One file's text, divided into coloured runs by the engine.
///
/// The division is the engine's because it runs the same lexer the analysis
/// does; a highlighter of our own would eventually disagree with the parser
/// about where a string ends, and then the code on screen would not be the
/// code that was read. See Sources/AtlasEngine/Graph/Highlighter.swift.
/// </summary>
public sealed record SourceSnippet
{
    [JsonPropertyName("path")]      public string Path { get; init; } = "";
    /// <summary>Empty when Atlas has no lexer for this file; then there is one plain run.</summary>
    [JsonPropertyName("language")]  public string Language { get; init; } = "";
    /// <summary>1-based line number of the first line of <see cref="Text"/>.</summary>
    [JsonPropertyName("firstLine")] public int FirstLine { get; init; }
    [JsonPropertyName("lineCount")] public int LineCount { get; init; }
    [JsonPropertyName("text")]      public string Text { get; init; } = "";
    [JsonPropertyName("spans")]     public IReadOnlyList<SourceSpan> Spans { get; init; } = [];
    /// <summary>Glossary terms appearing here, in the order a reader meets them.</summary>
    [JsonPropertyName("glossary")]  public IReadOnlyList<GlossaryTerm> Glossary { get; init; } = [];
}

public sealed record GlossaryTerm
{
    [JsonPropertyName("word")]  public string Word { get; init; } = "";
    [JsonPropertyName("title")] public string Title { get; init; } = "";
    [JsonPropertyName("body")]  public string Body { get; init; } = "";
}

/// <summary>
/// A run of bytes and what it is. Offsets are into the <b>UTF-8</b> of the
/// text — indexing a C# string by them directly would land mid-character on
/// anything outside ASCII.
/// </summary>
public sealed record SourceSpan
{
    [JsonPropertyName("o")] public int Offset { get; init; }
    [JsonPropertyName("n")] public int Length { get; init; }
    [JsonPropertyName("r")] public string Role { get; init; } = "plain";
}
