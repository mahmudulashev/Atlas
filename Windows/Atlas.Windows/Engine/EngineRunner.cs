using System.Diagnostics;
using System.Text.Json;

namespace Atlas.Windows.Engine;

/// <summary>How far along an analysis is. Mirrors Analyzer.Progress.</summary>
/// <param name="Stage">scanning | parsing | resolving | done</param>
public readonly record struct AnalysisProgress(string Stage, int Current, int Total)
{
    public double Fraction => Total > 0 ? Math.Clamp((double)Current / Total, 0, 1) : 0;
}

public sealed class EngineException(string message) : Exception(message);

/// <summary>
/// Runs atlas-engine and reads back what it found.
///
/// The analysis itself is Swift — the same code the macOS app links directly —
/// and this client never reimplements any of it. That is the whole point of
/// the split: a parser improvement lands once and both versions of Atlas get
/// it. What crosses the process boundary is one JSON document on stdout, and
/// a line of progress per few files on stderr.
/// </summary>
public sealed class EngineRunner(string enginePath)
{
    public string EnginePath { get; } = enginePath;

    /// <summary>
    /// Finds the engine binary.
    ///
    /// A shipped build keeps it beside the executable. ATLAS_ENGINE overrides
    /// that, and the SwiftPM output is tried last so the app runs from a
    /// working copy without anything being copied into place first.
    /// </summary>
    public static string? Locate()
    {
        string exe = OperatingSystem.IsWindows() ? "atlas-engine.exe" : "atlas-engine";

        var fromEnvironment = Environment.GetEnvironmentVariable("ATLAS_ENGINE");
        if (!string.IsNullOrWhiteSpace(fromEnvironment) && File.Exists(fromEnvironment))
            return fromEnvironment;

        var beside = Path.Combine(AppContext.BaseDirectory, exe);
        if (File.Exists(beside)) return beside;

        // Walk up looking for a checkout's build output.
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, ".build", "release", exe);
            if (File.Exists(candidate)) return candidate;
            directory = directory.Parent;
        }
        return null;
    }

    public async Task<Report> AnalyzeAsync(
        string projectPath,
        string language = "en",
        IProgress<AnalysisProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        var startInfo = new ProcessStartInfo(EnginePath)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        foreach (var argument in new[]
                 { "analyze", projectPath, "--lang", language, "--progress" })
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = new Process { StartInfo = startInfo };
        if (!process.Start())
            throw new EngineException($"could not start {EnginePath}");

        // stderr carries progress and, on failure, the reason. Both are read
        // while stdout streams, or a large report fills the pipe and the
        // engine blocks writing it.
        var diagnostics = new List<string>();
        var stderrPump = Task.Run(async () =>
        {
            string? line;
            while ((line = await process.StandardError.ReadLineAsync(cancellationToken)) is not null)
            {
                if (TryReadProgress(line, out var tick)) progress?.Report(tick);
                else if (line.Length > 0) diagnostics.Add(line);
            }
        }, cancellationToken);

        Report? report;
        try
        {
            report = await JsonSerializer.DeserializeAsync(
                process.StandardOutput.BaseStream, ReportContext.Default.Report,
                cancellationToken);
        }
        catch (JsonException error)
        {
            await process.WaitForExitAsync(CancellationToken.None);
            throw new EngineException(Describe(process.ExitCode, diagnostics, error.Message));
        }

        await stderrPump;
        await process.WaitForExitAsync(cancellationToken);

        if (process.ExitCode != 0 || report is null)
            throw new EngineException(Describe(process.ExitCode, diagnostics, null));

        if (report.Schema != Report.ExpectedSchema)
        {
            throw new EngineException(
                $"this build reads report schema {Report.ExpectedSchema}, but the engine " +
                $"produced schema {report.Schema}. The two halves are from different builds.");
        }
        return report;
    }

    /// <summary>
    /// Every interface string, in the requested language.
    ///
    /// Fetched from the engine rather than kept here, so the translations have
    /// exactly one home: Sources/AtlasEngine/Core/L10n.swift.
    /// </summary>
    public async Task<IReadOnlyDictionary<string, string>> StringsAsync(
        string language = "en", CancellationToken cancellationToken = default)
    {
        var startInfo = new ProcessStartInfo(EnginePath)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        startInfo.ArgumentList.Add("strings");
        startInfo.ArgumentList.Add("--lang");
        startInfo.ArgumentList.Add(language);

        using var process = new Process { StartInfo = startInfo };
        if (!process.Start()) throw new EngineException($"could not start {EnginePath}");

        var table = await JsonSerializer.DeserializeAsync(
            process.StandardOutput.BaseStream,
            ReportContext.Default.DictionaryStringString, cancellationToken);
        var complaint = await process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken);

        if (process.ExitCode != 0 || table is null)
            throw new EngineException(complaint.Trim() is { Length: > 0 } said
                ? said : $"the engine exited with code {process.ExitCode}");
        return table;
    }

    /// <summary>Progress arrives as one JSON object per line, e.g.
    /// <c>{"stage":"parsing","current":120,"total":333}</c>.</summary>
    private static bool TryReadProgress(string line, out AnalysisProgress progress)
    {
        progress = default;
        if (line.Length == 0 || line[0] != '{') return false;
        try
        {
            using var document = JsonDocument.Parse(line);
            var root = document.RootElement;
            if (!root.TryGetProperty("stage", out var stage)) return false;
            progress = new AnalysisProgress(
                stage.GetString() ?? "",
                root.TryGetProperty("current", out var c) ? c.GetInt32() : 0,
                root.TryGetProperty("total", out var t) ? t.GetInt32() : 0);
            return true;
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private static string Describe(int exitCode, List<string> diagnostics, string? parseError)
    {
        // The engine's own words first — it explains itself better than an
        // exit code does. See the EXIT section of `atlas-engine help`.
        var said = string.Join("\n", diagnostics).Trim();
        if (said.Length > 0) return said;
        return exitCode switch
        {
            1 => "the engine was asked for something it did not understand",
            2 => "there was no source the engine could read there",
            _ => parseError is null
                 ? $"the engine exited with code {exitCode}"
                 : $"the engine's output could not be read: {parseError}",
        };
    }
}
