using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Class;

public class CreateClassScheduleDto
{
    public Guid ClassID { get; set; }
    [Required]
    [StringLength(20)]
    [RegularExpression(@"^[A-Za-z\/\-\s,]+\z", ErrorMessage = "DaysOfWeek may only contain letters, slashes, hyphens, commas, and spaces.")]
    public required string DaysOfWeek { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
    [Required]
    [StringLength(50)]
    public required string Room { get; set; }
}
