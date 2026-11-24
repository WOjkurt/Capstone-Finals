using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;
using Api.Domain.Enrollment;

namespace Api.Domain.Grading;

public class Grade
{
    [Key]
    public Guid GradeID { get; set; }

    public Guid StudyLoadID { get; set; }
    public StudyLoad? StudyLoad { get; set; }

    public decimal? MidtermGrade { get; set; }
    public decimal? FinalGrade { get; set; }
    public int? Remarks { get; set; }

    public Guid SubmittedByUserID { get; set; }
    public User? SubmittedByUser { get; set; }

    public DateTime DateSubmitted { get; set; }

    // ── Changed after the fact, by the Registrar ─────────────────────────────
    // A grade that was corrected is not the same as one that was right first
    // time, and the student is entitled to know which they are looking at.
    // DateSubmitted alone cannot say so: a modification moves it, which would
    // quietly erase the fact that anything happened.

    /// <summary>When the Registrar last changed this grade. Null means nobody has.</summary>
    public DateTime? ModifiedAt { get; set; }

    public Guid? ModifiedByUserID { get; set; }
    public User? ModifiedByUser { get; set; }

    /// <summary>
    /// Why it was changed. Kept for the Registrar and the audit trail, and deliberately not
    /// shown to the student: it is written as an internal note, not as an explanation to them.
    /// </summary>
    [MaxLength(300)]
    public string? ModificationReason { get; set; }
}
