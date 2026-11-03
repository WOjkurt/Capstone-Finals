namespace Api.DTOs.Grading;

public class GradeResponseDto
{
    public Guid GradeId { get; set; }
    public Guid StudyLoadId { get; set; }
    public decimal? MidtermGrade { get; set; }
    public decimal? FinalGrade { get; set; }
    public int? Remarks { get; set; }
    public string? RemarksLabel { get; set; }
    public Guid SubmittedByUserID { get; set; }
    public string? TeacherName { get; set; }
    public DateTime DateSubmitted { get; set; }
    public Guid? StudentUserId { get; set; }
    public string? StudentName { get; set; }
    public string? SubjectCode { get; set; }
    public string? SubjectTitle { get; set; }
    public string? ClassName { get; set; }
    public decimal? Units { get; set; }
    public Guid? TermId { get; set; }
    public string? SchoolYear { get; set; }
    public int? Semester { get; set; }
    public string? TermLabel { get; set; }
    public int? LoadStatus { get; set; }
}
