using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Grading;

public class CreateGradeCorrectionDto
{
    public Guid GradeId { get; set; }
    [Range(1, 2)]
    public int CorrectionPeriod { get; set; } // 1 = Midterms, 2 = Finals
    [Range(typeof(decimal), "0.0", "5.0")]
    public decimal OldGrade { get; set; }
    [Range(typeof(decimal), "0.0", "5.0")]
    public decimal NewGrade { get; set; }
    [Required]
    [StringLength(500)]
    public required string Reason { get; set; }
}
