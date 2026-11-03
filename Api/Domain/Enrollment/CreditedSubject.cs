using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;

namespace Api.Domain.Enrollment;

/// <summary>
/// A DBTC subject the student is credited with because they passed it at another school
/// (transferees, shiftees). Counts as Passed for prerequisites, the study load builder and year-level promotion.
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

    public Guid RecordedByUserID { get; set; }
    public User? RecordedByUser { get; set; }

    public DateTime RecordedAt { get; set; }
}
