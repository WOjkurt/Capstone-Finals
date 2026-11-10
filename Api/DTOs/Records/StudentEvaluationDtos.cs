namespace Api.DTOs.Records;

/// <summary>A student's progress through their program's curriculum: what is done and what is left.</summary>
public class StudentEvaluationDto
{
    public Guid UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? Lrn { get; set; }
    public string? StudentID { get; set; }
    public string ProgramCode { get; set; } = string.Empty;
    public string ProgramName { get; set; } = string.Empty;
    public int? YearLevel { get; set; }
    public Guid? CurriculumId { get; set; }
    /// <summary>For example "2018 curriculum (from SY 2018-2019)"; empty for old records without one.</summary>
    public string? CurriculumName { get; set; }

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
    /// <summary>Passed, Credited, CrossEnrolled, PartiallyCredited, InProgress, Failed, Dropped, Withdrawn or NotTaken.</summary>
    public string Status { get; set; } = string.Empty;
    /// <summary>The final grade of the attempt that decided the status (a pass beats a fail).</summary>
    public decimal? FinalGrade { get; set; }
    public string? TermLabel { get; set; }
    /// <summary>For credited subjects: the other school and its grade as written.</summary>
    public string? CreditedFrom { get; set; }
    public string? CreditedGrade { get; set; }
    /// <summary>Units the Registrar credited (can be fewer than <see cref="Units"/>).</summary>
    public decimal? CreditedUnits { get; set; }
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
    /// <summary>Null keeps the current first name (older apps don't send it).</summary>
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.PlainNameConverter))] [Api.Common.PersonName] [System.ComponentModel.DataAnnotations.MaxLength(100)] public string? Firstname { get; set; }
    /// <summary>Null keeps the current last name.</summary>
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.PlainNameConverter))] [Api.Common.PersonName] [System.ComponentModel.DataAnnotations.MaxLength(100)] public string? Lastname { get; set; }
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.PlainNameConverter))] [Api.Common.PersonName] [System.ComponentModel.DataAnnotations.MaxLength(100)] public string? MiddleName { get; set; }
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.PlainNameConverter))] [Api.Common.PersonName] [System.ComponentModel.DataAnnotations.MaxLength(20)] public string? Suffix { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(300)] public string? Address { get; set; }
    public DateOnly? DateOfBirth { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(150)] public string? PlaceOfBirth { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(20)] public string? Sex { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(60)] public string? Nationality { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(200)] public string? EntranceData { get; set; }
    [System.ComponentModel.DataAnnotations.MaxLength(60)] public string? DateAdmitted { get; set; }
}

/// <summary>
/// Regular or irregular, and progress back to regular: an irregular student becomes regular again after
/// passing 6 units of back major subjects (majors they had failed or dropped before).
/// </summary>
public class StandingDto
{
    public Guid UserId { get; set; }
    public bool IsRegular { get; set; }
    public DateTime? IrregularSince { get; set; }
    /// <summary>Back major units passed since <see cref="IrregularSince"/>.</summary>
    public decimal BackMajorUnitsPassed { get; set; }
    public decimal UnitsToRegular { get; set; } = StandingRules.BackMajorUnitsToRegular;
    /// <summary>The back major subjects counted in <see cref="BackMajorUnitsPassed"/>.</summary>
    public List<string> CountedSubjects { get; set; } = new();
    /// <summary>Subjects failed or dropped at DBTC and not yet passed or fully credited.</summary>
    public List<string> UnresolvedSubjects { get; set; } = new();
    /// <summary>"MarkRegular", "MarkIrregular", or null when the status fits.</summary>
    public string? Suggestion { get; set; }
}

public class SetStandingDto
{
    public bool IsRegular { get; set; }
}

public static class StandingRules
{
    /// <summary>DBTC policy: units of back major subjects an irregular student must pass to be regular again.</summary>
    public const decimal BackMajorUnitsToRegular = 6m;
}

/// <summary>An irregular student and their progress back to regular.</summary>
public class IrregularStudentDto
{
    public Guid UserId { get; set; }
    public string StudentName { get; set; } = string.Empty;
    public string? Lrn { get; set; }
    public string? ProgramCode { get; set; }
    public int? YearLevel { get; set; }
    public DateTime? IrregularSince { get; set; }
    public decimal BackMajorUnitsPassed { get; set; }
    public bool ReadyToBeRegular { get; set; }
}

public class ShiftProgramDto
{
    public int ProgramId { get; set; }

    [System.ComponentModel.DataAnnotations.MaxLength(500)]
    public string Reason { get; set; } = string.Empty;
}

/// <summary>What the shift changed, and what the Registrar should look at next.</summary>
public class ShiftResultDto
{
    public string? FromProgramCode { get; set; }
    public int ProgramId { get; set; }
    public string ProgramCode { get; set; } = string.Empty;
    /// <summary>Old-program subjects the student is enrolled in and has no grade for yet.</summary>
    public int InProgressSubjects { get; set; }
    /// <summary>Old-program subjects still Pending; they may need rejecting.</summary>
    public int PendingSubjects { get; set; }
}

/// <summary>A subject passed or being taken in a previous program, which the Registrar may credit to the current one.</summary>
public class PreviousProgramSubjectDto
{
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public string ProgramCode { get; set; } = string.Empty;
    public decimal Units { get; set; }
    /// <summary>Passed or InProgress.</summary>
    public string Status { get; set; } = string.Empty;
    public decimal? FinalGrade { get; set; }
    public string SchoolYear { get; set; } = string.Empty;
    public string TermLabel { get; set; } = string.Empty;
    /// <summary>The current program's subject with the same code or title, if any.</summary>
    public Guid? SuggestedSubjectId { get; set; }
    public string? SuggestedSubjectCode { get; set; }
    public decimal? SuggestedUnits { get; set; }
    public bool AlreadyCredited { get; set; }
}

/// <summary>A subject the student took, with or without a grade: one row of the residency record and grade sheet.</summary>
public class StudentGradeRowDto
{
    public Guid StudyLoadId { get; set; }
    public Guid? GradeId { get; set; }
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public string ClassName { get; set; } = string.Empty;
    public decimal Units { get; set; }
    public decimal? MidtermGrade { get; set; }
    public decimal? FinalGrade { get; set; }
    /// <summary>1 Passed, 2 Failed, empty when there is no final grade yet.</summary>
    public int? Remarks { get; set; }
    public Guid TermId { get; set; }
    public string SchoolYear { get; set; } = string.Empty;
    public int Semester { get; set; }
    public string TermLabel { get; set; } = string.Empty;
    /// <summary>1 Enrolled, 2 Dropped, 3 Withdrawn.</summary>
    public int LoadStatus { get; set; }
    public string? TeacherName { get; set; }
}
