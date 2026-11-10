namespace Api.DTOs.Setup;

public class AcademicProgramDto
{
    public int ProgramID { get; set; }
    public required string ProgramCode { get; set; }
    public required string ProgramName { get; set; }
    public string? Major { get; set; }
    /// <summary>Name with the major, as printed on records.</summary>
    public string FullName => Api.Domain.Enrollment.AcademicProgram.FullNameOf(ProgramName, Major);
}
