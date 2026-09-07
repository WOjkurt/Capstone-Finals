namespace Api.DTOs.Grading;

public class SubmitGradeDto
{
    public Guid StudyLoadId { get; set; }
    public decimal? MidtermGrade { get; set; }
    public decimal? FinalGrade { get; set; }
}
