using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

public class AcademicTerm
{
    [Key]
    public Guid TermID { get; set; }
    public required string SchoolYear { get; set; }
    public int Semester { get; set; }
    public bool IsActive { get; set; } = false;

    /// <summary>First day old students can enroll for this term online. Set by the Registrar; empty means closed.</summary>
    public DateOnly? EnrollmentOpensOn { get; set; }

    /// <summary>Last day (included) old students can enroll for this term online.</summary>
    public DateOnly? EnrollmentClosesOn { get; set; }

    // ── Releasing results ────────────────────────────────────────────────
    // Separate from a student's own clearance, which is about that one student. This is the
    // school saying the term's results are finished and may be seen at all.

    /// <summary>
    /// When the Registrar released this term's grades, or null if they are still withheld.
    /// Existing terms were backfilled as released, so nothing a student could already see
    /// disappeared the day this arrived.
    /// </summary>
    public DateTime? GradesReleasedAt { get; set; }

    public Guid? GradesReleasedByUserID { get; set; }

    /// <summary>Whether a student may see this term's grades at all, before their own clearance.</summary>
    public bool AreGradesReleased => GradesReleasedAt != null;

    public bool IsEnrollmentOpen(DateOnly today) =>
        EnrollmentOpensOn is { } opens && EnrollmentClosesOn is { } closes && today >= opens && today <= closes;
}
