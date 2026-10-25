using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Enrollment;

public class UpdateYearLevelRequestDto
{
    [Required]
    [Range(1, 5, ErrorMessage = "yearLevel must be between 1 and 5.")]
    public int YearLevel { get; set; }
}
