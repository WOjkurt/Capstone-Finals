namespace Api.DTOs.Grading;

public class CreateGradeCorrectionDto
{
    public Guid GradeId { get; set; }
    public int CorrectionPeriod { get; set; } // 1 = Midterms, 2 = Finals
    public decimal OldGrade { get; set; }
    public decimal NewGrade { get; set; }
    public required string Reason { get; set; }
}
