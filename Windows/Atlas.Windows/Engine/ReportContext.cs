using System.Text.Json.Serialization;

namespace Atlas.Windows.Engine;

/// <summary>
/// Compile-time readers for everything the engine sends.
///
/// System.Text.Json reflects over types at runtime by default, which the
/// trimmer cannot follow: it has no way to know <see cref="Report"/>'s
/// properties are reachable, strips them, and leaves a deserializer that
/// silently returns nulls. Source generation writes the readers at build time
/// instead — so the trimmer can see them, and there is no reflection left to
/// pay for on a report with tens of thousands of call edges in it.
/// </summary>
[JsonSourceGenerationOptions(PropertyNameCaseInsensitive = false)]
[JsonSerializable(typeof(Report))]
[JsonSerializable(typeof(Dictionary<string, string>))]
internal partial class ReportContext : JsonSerializerContext;
