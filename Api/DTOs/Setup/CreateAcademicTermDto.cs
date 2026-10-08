using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Setup;

public class CreateAcademicTermDto
{
    public required string SchoolYear { get; set; }

    /// <summary>1 = 1st Semester, 2 = 2nd Semester, 3 = Summer Term.</summary>
    [Range(1, 3, ErrorMessage = "Semester must be 1 (1st Semester), 2 (2nd Semester), or 3 (Summer Term).")]
    public int Semester { get; set; }
}
