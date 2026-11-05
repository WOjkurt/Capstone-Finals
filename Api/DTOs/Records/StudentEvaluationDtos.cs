namespace Api.DTOs.Records;

/// <summary>A student's progress through their program's curriculum: what is done and what is left.</summary>
public class StudentEvaluationDto
{
    public Guid UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? Lrn { get; set; }
    public string ProgramCode { get; set; } = string.Empty;
    public string ProgramName { get; set; } = string.Empty;
    public int? YearLevel { get; set; }

    public decimal TotalUnits { get; set; }
    /// <summary>Passed or credited.</summary>
    public decimal EarnedUnits { get; set; }
    public decimal InProgressUnits { get; set; }
    public decimal RemainingUnits { get; set; }

    public List<EvaluationSubjectDto> Subjects { get; set; } = new();
}

public class EvaluationSubjectDto
{
    public Guid SubjectId { get; set; }
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public decimal Units { get; set; }
    public decimal LecHours { get; set; }
    public decimal LabHours { get; set; }
    /// <summary>Prerequisite codes and year standing as printed on the curriculum, e.g. "IT 101, 3rd year standing".</summary>
    public string? Prerequisites { get; set; }
    public string? Corequisites { get; set; }
    public int YearLevel { get; set; }
    public int Semester { get; set; }
    public bool IsMinor { get; set; }
    /// <summary>Passed, Credited, InProgress, Failed, Dropped or NotTaken.</summary>
    public string Status { get; set; } = string.Empty;
    /// <summary>The final grade of the attempt that decided the status (a pass beats a fail).</summary>
    public decimal? FinalGrade { get; set; }
    public string? TermLabel { get; set; }
    /// <summary>For credited subjects: the other school and its grade as written.</summary>
    public string? CreditedFrom { get; set; }
    public string? CreditedGrade { get; set; }
}

/// <summary>Everything printed on the Transcript of Records.</summary>
public class TranscriptDto
{
    public Guid UserId { get; set; }
    /// <summary>"LASTNAME, Firstname Middlename Suffix" from the enrollment form when there is one.</summary>
    public string FullName { get; set; } = string.Empty;
    public string? Lrn { get; set; }
    public string ProgramCode { get; set; } = string.Empty;
    public string ProgramName { get; set; } = string.Empty;
    public string? Address { get; set; }
    public DateOnly? DateOfBirth { get; set; }
    public string? PlaceOfBirth { get; set; }
    public string? Sex { get; set; }
    public string? Nationality { get; set; }
    /// <summary>The first term the student was enrolled in, e.g. "1st Semester, 2025-2026".</summary>
    public string? DateAdmitted { get; set; }
    /// <summary>Last school attended before DBTC (from the enrollment form).</summary>
    public string? EntranceData { get; set; }
    public List<TranscriptTermDto> Terms { get; set; } = new();
    public List<TranscriptCreditGroupDto> Credits { get; set; } = new();
}

public class TranscriptTermDto
{
    /// <summary>"1st Semester, 2025-2026" or "Summer, 2025-2026", as written on a transcript.</summary>
    public string Heading { get; set; } = string.Empty;
    public List<TranscriptRowDto> Rows { get; set; } = new();
}

public class TranscriptRowDto
{
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    /// <summary>"1.75", "5.00", "DO" (dropped officially), "W" (withdrawn), or empty when not graded yet.</summary>
    public string Final { get; set; } = string.Empty;
    public decimal Units { get; set; }
}

public class TranscriptCreditGroupDto
{
    public string SourceSchool { get; set; } = string.Empty;
    public List<TranscriptRowDto> Rows { get; set; } = new();
}

/// <summary>
/// A student's personal details for their records. Each value is the Registrar's saved one, or else the
/// enrollment form's; <see cref="FromForm"/> names the fields that came from the form.
/// </summary>
public class PersonalDetailsDto
{
    public Guid UserId { get; set; }
    public string Firstname { get; set; } = string.Empty;
    public string Lastname { get; set; } = string.Empty;
    public string? MiddleName { get; set; }
    public string? Suffix { get; set; }
    public string? Address { get; set; }
    public DateOnly? DateOfBirth { get; set; }
    public string? PlaceOfBirth { get; set; }
    public string? Sex { get; set; }
    public string? Nationality { get; set; }
    public string? EntranceData { get; set; }
    public string? DateAdmitted { get; set; }
    /// <summary>The first term the student was enrolled in, used when <see cref="DateAdmitted"/> is empty.</summary>
    public string? FirstTermEnrolled { get; set; }
    public bool HasEnrollmentForm { get; set; }
    public List<string> FromForm { get; set; } = new();
    public string? UpdatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>What the Registrar saves. An empty field means "use the enrollment form".</summary>
public class UpdatePersonalDetailsDto
{
    [System.ComponentModel.DataAnnotations.MaxLength(100)] public string? MiddleName { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(20)] public string? Suffix { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(300)] public string? Address { get; set; }
    public DateOnly? DateOfBirth { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(150)] public string? PlaceOfBirth { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(20)] public string? Sex { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(60)] public string? Nationality { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(200)] public string? EntranceData { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(60)] public string? DateAdmitted { get; set; }
}
