namespace Api.DTOs.Records;

/// <summary>Students in the final year of their curriculum and what each still needs to graduate.</summary>
public class GraduationCandidatesDto
{
    /// <summary>All required subjects passed or credited.</summary>
    public int Complete { get; set; }
    /// <summary>Nothing left except subjects they are taking now.</summary>
    public int FinishingThisTerm { get; set; }
    /// <summary>Still lacking subjects they aren't taking.</summary>
    public int Lacking { get; set; }
    public List<GraduationCandidateDto> Rows { get; set; } = new();
}

/// <summary>Same keys as a student search result, so the app can open the student from it.</summary>
public class GraduationCandidateDto
{
    public Guid UserId { get; set; }
    public string Firstname { get; set; } = string.Empty;
    public string Lastname { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? StudentId { get; set; }
    public string? Lrn { get; set; }
    public int? ProgramId { get; set; }
    public string? ProgramCode { get; set; }
    public string? ProgramName { get; set; }
    public int? YearLevel { get; set; }
    public string? CurriculumName { get; set; }
    public bool HasSignedIn { get; set; }
    public int Role { get; set; } = 5;

    /// <summary>"Complete", "FinishingThisTerm" or "Lacking".</summary>
    public string Status { get; set; } = string.Empty;
    public decimal TotalUnits { get; set; }
    public decimal EarnedUnits { get; set; }
    public decimal InProgressUnits { get; set; }
    public List<GraduationSubjectDto> InProgress { get; set; } = new();
    public List<GraduationSubjectDto> LackingSubjects { get; set; } = new();
}

public class GraduationSubjectDto
{
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public decimal Units { get; set; }
    public int YearLevel { get; set; }
    public int Semester { get; set; }
    /// <summary>The evaluation status: InProgress, NotTaken, Failed, Dropped, Withdrawn or PartiallyCredited.</summary>
    public string Status { get; set; } = string.Empty;
}
