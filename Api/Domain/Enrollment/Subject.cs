using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

public class Subject
{
    [Key]
    public Guid SubjectID { get; set; }
    public required string SubjectCode { get; set; }
    public required string SubjectTitle { get; set; }
    public decimal LecUnits { get; set; }
    public decimal LabUnits { get; set; }
    public decimal LecHours { get; set; }
    public decimal LabHours { get; set; }

    public int ProgramID { get; set; }
    public AcademicProgram? Program { get; set; }

    public int YearLevel { get; set; }
    public int DefaultSemester { get; set; }
}
