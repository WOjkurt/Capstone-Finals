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
