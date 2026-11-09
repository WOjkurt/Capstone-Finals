namespace Api.DTOs.Enrollment;

public class StudentSearchResultDto
{
    public Guid UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? Email { get; set; }
    /// <summary>False for students imported from the registrar's records who have not signed in yet.</summary>
    public bool HasSignedIn { get; set; } = true;
    public string? Lrn { get; set; }
    public string? StudentID { get; set; }
    public bool HasLrn { get; set; }
    public int? ProgramId { get; set; }
    public string? ProgramCode { get; set; }
    public string? ProgramName { get; set; }
    public int? YearLevel { get; set; }
    public Guid? CurriculumId { get; set; }
    public string? CurriculumName { get; set; }
    public int? StudentType { get; set; }
    public int? StudentStatus { get; set; }
    public string? Status { get; set; }
}
