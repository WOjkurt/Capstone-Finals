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

    public bool IsEnrollmentOpen(DateOnly today) =>
        EnrollmentOpensOn is { } opens && EnrollmentClosesOn is { } closes && today >= opens && today <= closes;
}
