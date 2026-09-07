namespace Api.DTOs.Setup;

public class CreateSubjectDto
{
    public required string SubjectCode { get; set; }
    public required string SubjectTitle { get; set; }
    public decimal LecUnits { get; set; }
    public decimal LabUnits { get; set; }
    public decimal LecHours { get; set; }
    public decimal LabHours { get; set; }
    public int ProgramID { get; set; }
    public int YearLevel { get; set; }
    public int DefaultSemester { get; set; }
}
