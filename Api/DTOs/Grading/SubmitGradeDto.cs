using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Grading;

public class SubmitGradeDto
{
    public Guid StudyLoadId { get; set; }
    [Range(typeof(decimal), "0.0", "5.0")]
    public decimal? MidtermGrade { get; set; }
    [Range(typeof(decimal), "0.0", "5.0")]
    public decimal? FinalGrade { get; set; }
}
