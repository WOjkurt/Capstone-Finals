namespace Api.DTOs.Records;

/// <summary>Students → Records check: what each active student still needs before their records are complete.</summary>
public class RecordsCheckDto
{
    public int ActiveStudents { get; set; }
    /// <summary>Count per issue key, in the order shown (see <see cref="RecordsCheckIssues"/>).</summary>
    public List<RecordsCheckCountDto> Counts { get; set; } = new();
    /// <summary>Only students with at least one issue, sorted by name.</summary>
    public List<RecordsCheckRowDto> Rows { get; set; } = new();
}

public class RecordsCheckCountDto
{
    public string Key { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
    public int Count { get; set; }
}

/// <summary>Same keys as a student search result, so the app can open the student from it.</summary>
public class RecordsCheckRowDto
{
    public Guid UserId { get; set; }
    public string Firstname { get; set; } = string.Empty;
    public string Lastname { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? StudentId { get; set; }
    public string? Lrn { get; set; }
    public int? ProgramId { get; set; }
    public string? ProgramCode { get; set; }
    public int? YearLevel { get; set; }
    public bool HasSignedIn { get; set; }
    public int Role { get; set; } = 5;
    public List<string> Issues { get; set; } = new();
    /// <summary>For the "transcript" issue: the missing transcript fields.</summary>
    public List<string> Missing { get; set; } = new();
}

public static class RecordsCheckIssues
{
    public const string NoStudentId = "no-student-id";
    public const string NoEmail = "no-email";
    public const string NotSignedIn = "not-signed-in";
    public const string NoProgram = "no-program";
    public const string NoYearLevel = "no-year-level";
    public const string NoCurriculum = "no-curriculum";
    public const string Transcript = "transcript";

    public static readonly (string Key, string Label)[] All =
    {
        (NoEmail, "No school email (can't sign in)"),
        (NoStudentId, "No Student ID"),
        (NoProgram, "No program"),
        (NoYearLevel, "No year level"),
        (NoCurriculum, "No curriculum"),
        (Transcript, "Missing transcript details"),
        (NotSignedIn, "Email set, not signed in yet"),
    };
}
