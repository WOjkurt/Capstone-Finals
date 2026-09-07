using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

public class AcademicProgram
{
    [Key]
    public int ProgramID { get; set; }
    public required string ProgramCode { get; set; }
    public required string ProgramName { get; set; }
}
