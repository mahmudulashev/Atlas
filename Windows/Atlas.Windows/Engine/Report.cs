using System.Text.Json.Serialization;

namespace Atlas.Windows.Engine;

/// <summary>
/// The wire format atlas-engine produces, mirrored field for field.
///
/// The Swift side is the authority: Sources/AtlasCLI/Report.swift defines
/// this, and <see cref="Report.Schema"/> is checked on load so a mismatched
/// pair says so rather than misreading the numbers.
///
/// Indices are the vocabulary, exactly as in the graph. A symbol's
/// <c>File</c> indexes <c>Files</c>; a call's <c>F</c>/<c>T</c> index
/// <c>Symbols</c>; a diagram card's <c>Node</c> indexes
/// <c>Diagram.Nodes</c>. Nothing is looked up by string.
///
/// Optionals are omitted rather than written as null, which is why the
/// nullable types here matter: a missing Container, Symbol, From, Diagram or
/// Drift simply is not in the document.
/// </summary>
public sealed record Report
{
    /// <summary>The schema this client understands.</summary>
    public const int ExpectedSchema = 2;

    [JsonPropertyName("schema")]    public int Schema { get; init; }
    [JsonPropertyName("project")]   public ProjectInfo Project { get; init; } = new();
    [JsonPropertyName("files")]     public IReadOnlyList<FileEntry> Files { get; init; } = [];
    [JsonPropertyName("symbols")]   public IReadOnlyList<SymbolEntry> Symbols { get; init; } = [];
    [JsonPropertyName("calls")]     public IReadOnlyList<Call> Calls { get; init; } = [];
    [JsonPropertyName("fileEdges")] public IReadOnlyList<FileEdge> FileEdges { get; init; } = [];
    [JsonPropertyName("hubs")]      public IReadOnlyList<int> Hubs { get; init; } = [];
    [JsonPropertyName("map")]       public MapInfo? Map { get; init; }
    [JsonPropertyName("issues")]    public IReadOnlyList<IssueEntry> Issues { get; init; } = [];
    [JsonPropertyName("route")]     public IReadOnlyList<RouteStep> Route { get; init; } = [];
    [JsonPropertyName("drift")]     public DriftReport? Drift { get; init; }
}

public sealed record ProjectInfo
{
    [JsonPropertyName("name")]         public string Name { get; init; } = "";
    [JsonPropertyName("root")]         public string Root { get; init; } = "";
    /// <summary>Stable key, e.g. "web framework". Match on this, not the label.</summary>
    [JsonPropertyName("kind")]         public string Kind { get; init; } = "";
    /// <summary>The same thing in the language the report was asked for.</summary>
    [JsonPropertyName("kindLabel")]    public string KindLabel { get; init; } = "";
    /// <summary>What that kind of thing is, in prose — the opening sentence.</summary>
    [JsonPropertyName("kindExplanation")] public string KindExplanation { get; init; } = "";
    [JsonPropertyName("fileCount")]    public int FileCount { get; init; }
    [JsonPropertyName("lineCount")]    public int LineCount { get; init; }
    [JsonPropertyName("symbolCount")]  public int SymbolCount { get; init; }
    [JsonPropertyName("callCount")]    public int CallCount { get; init; }
    [JsonPropertyName("parseSeconds")] public double ParseSeconds { get; init; }
    [JsonPropertyName("analysedAt")]   public DateTimeOffset AnalysedAt { get; init; }
    [JsonPropertyName("languages")]    public IReadOnlyList<LanguageCount> Languages { get; init; } = [];
}

public sealed record LanguageCount
{
    [JsonPropertyName("id")]    public string Id { get; init; } = "";
    [JsonPropertyName("name")]  public string Name { get; init; } = "";
    [JsonPropertyName("files")] public int Files { get; init; }
}

public sealed record FileEntry
{
    /// <summary>Relative to the project root, always separated by '/'.</summary>
    [JsonPropertyName("path")]      public string Path { get; init; } = "";
    [JsonPropertyName("name")]      public string Name { get; init; } = "";
    [JsonPropertyName("directory")] public string Directory { get; init; } = "";
    [JsonPropertyName("language")]  public string Language { get; init; } = "";
}

public sealed record SymbolEntry
{
    [JsonPropertyName("name")]       public string Name { get; init; } = "";
    [JsonPropertyName("container")]  public string? Container { get; init; }
    [JsonPropertyName("display")]    public string Display { get; init; } = "";
    [JsonPropertyName("kind")]       public string Kind { get; init; } = "";
    [JsonPropertyName("language")]   public string Language { get; init; } = "";
    /// <summary>Index into <see cref="Report.Files"/>; -1 when it has no file.</summary>
    [JsonPropertyName("file")]       public int File { get; init; }
    [JsonPropertyName("line")]       public int Line { get; init; }
    [JsonPropertyName("endLine")]    public int EndLine { get; init; }
    [JsonPropertyName("fanIn")]      public int FanIn { get; init; }
    [JsonPropertyName("fanOut")]     public int FanOut { get; init; }
    [JsonPropertyName("external")]   public bool External { get; init; }
    [JsonPropertyName("branches")]   public int Branches { get; init; }
    [JsonPropertyName("nesting")]    public int Nesting { get; init; }
    /// <summary>easy | moderate | hard</summary>
    [JsonPropertyName("difficulty")] public string Difficulty { get; init; } = "";

    public int Span => Math.Max(1, EndLine - Line + 1);
}

/// <summary>
/// One call edge. Short names because a large project has tens of thousands
/// of these and they dominate the document.
/// </summary>
public sealed record Call
{
    [JsonPropertyName("f")] public int From { get; init; }
    [JsonPropertyName("t")] public int To { get; init; }
    [JsonPropertyName("n")] public int Sites { get; init; }
}

/// <summary>A file-to-file dependency taken from imports rather than calls.</summary>
public sealed record FileEdge
{
    [JsonPropertyName("f")] public int From { get; init; }
    [JsonPropertyName("t")] public int To { get; init; }
}

/// <summary>
/// The call ladder, already placed by the engine.
///
/// The layout travels with the data because it is deliberate — depth by
/// longest path, then barycentre sweeps to reduce crossings — and because the
/// picture is the product. Two clients each deriving their own would draw the
/// same repository two different ways. Coordinates are absolute on a canvas of
/// <see cref="Canvas"/> size, so this client only pans and zooms.
/// </summary>
public sealed record MapInfo
{
    [JsonPropertyName("canvas")]  public CanvasSize Canvas { get; init; } = new();
    [JsonPropertyName("nodes")]   public IReadOnlyList<MapNode> Nodes { get; init; } = [];
    [JsonPropertyName("boxes")]   public IReadOnlyList<Box> Boxes { get; init; } = [];
    /// <summary>Node indices per column, in the order they are stacked.</summary>
    [JsonPropertyName("columns")] public IReadOnlyList<IReadOnlyList<int>> Columns { get; init; } = [];
    [JsonPropertyName("edges")]   public IReadOnlyList<MapEdge> Edges { get; init; } = [];
    /// <summary>Indices into <see cref="Nodes"/>.</summary>
    [JsonPropertyName("cycles")]  public IReadOnlyList<IReadOnlyList<int>> Cycles { get; init; } = [];
    /// <summary>The same dependency data arranged as a grid rather than a ladder.</summary>
    [JsonPropertyName("matrix")]  public MatrixInfo Matrix { get; init; } = new();
}

/// <summary>Row and column order for the dependency matrix: rows call columns.</summary>
public sealed record MatrixInfo
{
    /// <summary>Node indices, in the order they are laid out.</summary>
    [JsonPropertyName("order")]     public IReadOnlyList<int> Order { get; init; } = [];
    [JsonPropertyName("districts")] public IReadOnlyList<MatrixDistrict> Districts { get; init; } = [];
}

public sealed record MatrixDistrict
{
    /// <summary>interface | logic | data — a key, printed by the client.</summary>
    [JsonPropertyName("key")]   public string Key { get; init; } = "";
    /// <summary>Where this district starts in <see cref="MatrixInfo.Order"/>.</summary>
    [JsonPropertyName("start")] public int Start { get; init; }
}

public sealed record CanvasSize
{
    [JsonPropertyName("w")] public double Width { get; init; }
    [JsonPropertyName("h")] public double Height { get; init; }
}

public sealed record MapNode
{
    /// <summary>Index into <see cref="Report.Files"/>.</summary>
    [JsonPropertyName("file")]        public int File { get; init; }
    [JsonPropertyName("path")]        public string Path { get; init; } = "";
    [JsonPropertyName("name")]        public string Name { get; init; } = "";
    /// <summary>Stable key — drives the district rule down the box's left edge.</summary>
    [JsonPropertyName("layer")]       public string Layer { get; init; } = "";
    [JsonPropertyName("layerLabel")]  public string LayerLabel { get; init; } = "";
    [JsonPropertyName("language")]    public string Language { get; init; } = "";
    /// <summary>Indices into <see cref="Report.Symbols"/>, most connected first.</summary>
    [JsonPropertyName("symbols")]     public IReadOnlyList<int> Symbols { get; init; } = [];
    [JsonPropertyName("symbolCount")] public int SymbolCount { get; init; }
    [JsonPropertyName("lines")]       public int Lines { get; init; }
    [JsonPropertyName("fanIn")]       public int FanIn { get; init; }
    [JsonPropertyName("fanOut")]      public int FanOut { get; init; }
}

public sealed record Box
{
    /// <summary>Index into <see cref="MapInfo.Nodes"/>.</summary>
    [JsonPropertyName("node")]   public int Node { get; init; }
    [JsonPropertyName("x")]      public double X { get; init; }
    [JsonPropertyName("y")]      public double Y { get; init; }
    [JsonPropertyName("w")]      public double Width { get; init; }
    [JsonPropertyName("h")]      public double Height { get; init; }
    [JsonPropertyName("column")] public int Column { get; init; }
    [JsonPropertyName("row")]    public int Row { get; init; }
}

/// <summary>A file-to-file dependency, weighted by how many call sites back it.</summary>
public sealed record MapEdge
{
    [JsonPropertyName("f")]      public int From { get; init; }
    [JsonPropertyName("t")]      public int To { get; init; }
    [JsonPropertyName("weight")] public int Weight { get; init; }
}

public sealed record IssueEntry
{
    [JsonPropertyName("id")]       public int Id { get; init; }
    [JsonPropertyName("kind")]     public string Kind { get; init; } = "";
    /// <summary>low | medium | high</summary>
    [JsonPropertyName("severity")] public string Severity { get; init; } = "";
    [JsonPropertyName("title")]    public string Title { get; init; } = "";
    [JsonPropertyName("subject")]  public string Subject { get; init; } = "";
    [JsonPropertyName("detail")]   public string Detail { get; init; } = "";
    [JsonPropertyName("advice")]   public string Advice { get; init; } = "";
    [JsonPropertyName("file")]     public string File { get; init; } = "";
    [JsonPropertyName("line")]     public int Line { get; init; }
    /// <summary>Index into <see cref="Report.Symbols"/>, when there is a jump target.</summary>
    [JsonPropertyName("symbol")]   public int? Symbol { get; init; }
}

public sealed record RouteStep
{
    /// <summary>Index into <see cref="Report.Symbols"/>.</summary>
    [JsonPropertyName("symbol")] public int Symbol { get; init; }
    /// <summary>The step that calls this one; absent for the first.</summary>
    [JsonPropertyName("from")]   public int? From { get; init; }
    /// <summary>How many symbols this step can reach, counted by the engine.</summary>
    [JsonPropertyName("reach")]  public int Reach { get; init; }
}

public sealed record DriftReport
{
    [JsonPropertyName("previousScan")] public DateTimeOffset? PreviousScan { get; init; }
    [JsonPropertyName("entries")]      public IReadOnlyList<DriftEntry> Entries { get; init; } = [];
}

public sealed record DriftEntry
{
    [JsonPropertyName("kind")]        public string Kind { get; init; } = "";
    /// <summary>Empty for the aggregate kinds, where the count is the whole story.</summary>
    [JsonPropertyName("subject")]     public string Subject { get; init; } = "";
    [JsonPropertyName("delta")]       public int Delta { get; init; }
    [JsonPropertyName("detail")]      public string Detail { get; init; } = "";
    /// <summary>The change written out as a sentence, composed by the engine.</summary>
    [JsonPropertyName("note")]        public string Note { get; init; } = "";
    [JsonPropertyName("regression")]  public bool Regression { get; init; }
    [JsonPropertyName("improvement")] public bool Improvement { get; init; }
}
