namespace Api.DTOs.Grading;

public class GradeCorrectionResponseDto
{
    public Guid CorrectionId { get; set; }
    public Guid GradeId { get; set; }
    public int CorrectionPeriod { get; set; }
    public required string CorrectionPeriodLabel { get; set; }
    public decimal OldGrade { get; set; }
    public decimal NewGrade { get; set; }
    public required string Reason { get; set; }
    public Guid RequestedByUserID { get; set; }
    public string? RequesterName { get; set; }
    public Guid? ReviewedByUserID { get; set; }
    public string? ReviewerName { get; set; }
    public int CorrectionStatus { get; set; }
    public required string CorrectionStatusLabel { get; set; }
    public DateTime DateRequested { get; set; }
    public DateTime? DateReviewed { get; set; }
    public string? SubjectCode { get; set; }
    public string? SubjectTitle { get; set; }
    public string? StudentName { get; set; }
}
