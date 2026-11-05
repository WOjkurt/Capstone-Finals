using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;

namespace Api.Domain.Enrollment;

/// <summary>
/// A DBTC subject the student is credited with because they passed it at another school: before coming to
/// DBTC (transferees, shiftees) or while enrolled here (cross-enrollment). With its full units it counts as
/// Passed for prerequisites, the study load builder and year-level promotion.
/// </summary>
public class CreditedSubject
{
    [Key]
    public Guid CreditedSubjectID { get; set; }

    public Guid UserID { get; set; }
    public User? User { get; set; }

    public Guid SubjectID { get; set; }
    public Subject? Subject { get; set; }

    [MaxLength(200)]
    public required string SourceSchool { get; set; }

    /// <summary>The subject code at the other school, as written on their records.</summary>
    [MaxLength(50)]
    public string? SourceSubjectCode { get; set; }

    /// <summary>The grade as written by the other school (not converted).</summary>
    [MaxLength(20)]
    public string? Grade { get; set; }

    [MaxLength(20)]
    public string? SchoolYear { get; set; }

    /// <summary>
    /// Units the Registrar credits, which can be less than the DBTC subject's units (for example when the
    /// student attended only part of the class). The subject counts as passed only with its full units.
    /// </summary>
    public decimal CreditedUnits { get; set; }

    /// <summary>One of <see cref="CreditKinds"/>.</summary>
    public int Kind { get; set; } = CreditKinds.Transfer;

    /// <summary>For cross-enrollment: the DBTC term the subject was taken during.</summary>
    public Guid? TermID { get; set; }
    public AcademicTerm? Term { get; set; }

    public Guid RecordedByUserID { get; set; }
    public User? RecordedByUser { get; set; }

    public DateTime RecordedAt { get; set; }
}

public static class CreditKinds
{
    /// <summary>Taken before DBTC (transferee) or in a previous program (shiftee).</summary>
    public const int Transfer = 1;

    /// <summary>Taken at another school while enrolled at DBTC.</summary>
    public const int CrossEnrollment = 2;
}
