using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Credits;

public class CreateCreditedSubjectDto
{
    public Guid UserId { get; set; }
    public Guid SubjectId { get; set; }

    [Required, MaxLength(200)]
    public string SourceSchool { get; set; } = string.Empty;

    [MaxLength(50)]
    public string? SourceSubjectCode { get; set; }

    [MaxLength(20)]
    public string? Grade { get; set; }

    [MaxLength(20)]
    public string? SchoolYear { get; set; }

    /// <summary>Units credited, entered by the Registrar (more than 0, at most the DBTC subject's units).</summary>
    public decimal CreditedUnits { get; set; }

    /// <summary>1 = from a previous school, 2 = cross-enrolled during a DBTC term.</summary>
    public int Kind { get; set; } = 1;

    /// <summary>Required for cross-enrollment: the DBTC term it was taken during.</summary>
    public Guid? TermId { get; set; }
}

public class CreditedSubjectDto
{
    public Guid CreditedSubjectId { get; set; }
    public Guid UserId { get; set; }
    public Guid SubjectId { get; set; }
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public decimal Units { get; set; }
    public int YearLevel { get; set; }
    public string SourceSchool { get; set; } = string.Empty;
    public string? SourceSubjectCode { get; set; }
    public string? Grade { get; set; }
    public string? SchoolYear { get; set; }
    public string? RecordedBy { get; set; }
    public DateTime RecordedAt { get; set; }
    public decimal CreditedUnits { get; set; }
    /// <summary>Fewer units credited than the subject has; the subject still has to be taken.</summary>
    public bool IsPartial { get; set; }
    public int Kind { get; set; }
    public Guid? TermId { get; set; }
    public string? TermLabel { get; set; }
}

/// <summary>What importing a list of credited subjects would do (dry run) or did.</summary>
public class CreditsImportResultDto
{
    public bool DryRun { get; set; }
    /// <summary>Subjects that will be (or were) credited.</summary>
    public int Credits { get; set; }
    /// <summary>Students who get at least one new credit.</summary>
    public int Students { get; set; }
    /// <summary>Rows already credited from an earlier import or by hand; skipped.</summary>
    public int AlreadyCredited { get; set; }
    /// <summary>The credits, at most 300 listed.</summary>
    public List<CreditsImportRowDto> Rows { get; set; } = new();
    public List<Api.DTOs.Records.RecordsImportProblemDto> Problems { get; set; } = new();
    public int TotalProblems { get; set; }

    /// <summary>What was saved, for the activity log; not sent to the app.</summary>
    [System.Text.Json.Serialization.JsonIgnore]
    public List<(Api.Domain.Enrollment.CreditedSubject Credit, Api.Domain.Enrollment.Subject Subject)> Added { get; set; } = new();
}

public class CreditsImportRowDto
{
    public string StudentId { get; set; } = string.Empty;
    public string StudentName { get; set; } = string.Empty;
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public decimal CreditedUnits { get; set; }
    public decimal Units { get; set; }
    public string SourceSchool { get; set; } = string.Empty;
    public string? Grade { get; set; }
    public int Kind { get; set; }
}
