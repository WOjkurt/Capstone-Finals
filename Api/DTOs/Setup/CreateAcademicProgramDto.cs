namespace Api.DTOs.Setup;

public class CreateAcademicProgramDto
{
    public required string ProgramCode { get; set; }
    public required string ProgramName { get; set; }

    /// <summary>Optional, e.g. "Mechanical Technology" (without "Major in").</summary>
    [System.ComponentModel.DataAnnotations.StringLength(100)]
    public string? Major { get; set; }
}
