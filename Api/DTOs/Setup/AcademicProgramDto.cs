namespace Api.DTOs.Setup;

public class AcademicProgramDto
{
    public int ProgramID { get; set; }
    public required string ProgramCode { get; set; }
    public required string ProgramName { get; set; }
}
