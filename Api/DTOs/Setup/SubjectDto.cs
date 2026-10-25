namespace Api.DTOs.Setup;

public class SubjectDto
{
    public Guid SubjectID { get; set; }
    public required string SubjectCode { get; set; }
    public required string SubjectTitle { get; set; }
    public decimal LecUnits { get; set; }
    public decimal LabUnits { get; set; }
    public decimal LecHours { get; set; }
    public decimal LabHours { get; set; }
    public int ProgramID { get; set; }
    public string? ProgramCode { get; set; }
    public int YearLevel { get; set; }
    public int DefaultSemester { get; set; }
    public int? StandingYear { get; set; }

    public List<PrerequisiteDto> Prerequisites { get; set; } = new();
}
