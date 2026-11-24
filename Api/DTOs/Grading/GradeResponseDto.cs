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

    /// <summary>
    /// When the Registrar last changed this grade, or null if nobody has. Sent to the student
    /// too: a mark that was corrected is not the same as one that was right the first time, and
    /// they should not have to notice the number quietly differing from what they wrote down.
    /// The reason behind it is an internal note and stays out of this.
    /// </summary>
    public DateTime? ModifiedAt { get; set; }

    /// <summary>
    /// Whether the Registrar may still change this one — true only in the term that is active.
    /// Decided here rather than in the app so the two cannot disagree: an Edit button that leads
    /// to a refusal is worse than no Edit button.
    /// </summary>
    public bool CanModify { get; set; }
    public int? LoadStatus { get; set; }
}
