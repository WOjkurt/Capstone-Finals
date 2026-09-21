using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Grading;

public class ReviewGradeCorrectionDto
{
    [StringLength(500)]
    public string? Reason { get; set; }
}
