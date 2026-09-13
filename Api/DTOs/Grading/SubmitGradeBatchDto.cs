namespace Api.DTOs.Grading;

public class SubmitGradeBatchDto
{
    public Guid ClassId { get; set; }
    public List<SubmitGradeBatchItemDto> Grades { get; set; } = new();
}

public class SubmitGradeBatchItemDto
{
    public Guid StudyLoadId { get; set; }
    public decimal? MidtermGrade { get; set; }
    public decimal? FinalGrade { get; set; }
}
