using System.Text.Json.Serialization;

namespace Api.DTOs.Class;

public class OpenTermRequestDto
{
    public int ProgramId { get; set; }
    public Guid TermId { get; set; }

    /// <summary>
    /// Optional year level filter (1–4). Null means all year levels.
    /// </summary>
    public int? YearLevel { get; set; }

    /// <summary>
    /// Number of sections to create per subject (A, B, C…). Default 1, max 6.
    /// </summary>
    public int Sections { get; set; } = 1;
}

public class OpenTermResultDto
{
    [JsonPropertyName("dryRun")]
    public bool DryRun { get; set; }

    [JsonPropertyName("termId")]
    public Guid TermId { get; set; }

    [JsonPropertyName("programId")]
    public int ProgramId { get; set; }

    [JsonPropertyName("plannedCount")]
    public int PlannedCount { get; set; }

    [JsonPropertyName("createdCount")]
    public int CreatedCount { get; set; }

    [JsonPropertyName("skippedExisting")]
    public int SkippedExisting { get; set; }

    [JsonPropertyName("skippedNoDefaultSemester")]
    public int SkippedNoDefaultSemester { get; set; }

    [JsonPropertyName("perYear")]
    public Dictionary<int, int> PerYear { get; set; } = new();

    [JsonPropertyName("termIsActive")]
    public bool TermIsActive { get; set; }

    [JsonPropertyName("sampleClassNames")]
    public List<string> SampleClassNames { get; set; } = new();

    // ── Compatibility accessors for existing tests ──
    [JsonIgnore]
    public bool IsDryRun
    {
        get => DryRun;
        set => DryRun = value;
    }

    [JsonIgnore]
    public int Created
    {
        get => CreatedCount;
        set => CreatedCount = value;
    }

    [JsonIgnore]
    public int WouldCreate
    {
        get => PlannedCount;
        set => PlannedCount = value;
    }
}
