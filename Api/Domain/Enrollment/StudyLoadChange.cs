using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

/// <summary>
/// A subject added, dropped, withdrawn or re-enrolled after the student was enrolled for the term,
/// with the Registrar's reason. Printed on the Adding/Dropping form.
/// </summary>
public class StudyLoadChange
{
    [Key]
    public Guid ChangeID { get; set; }

    public Guid StudyLoadID { get; set; }
    public StudyLoad? StudyLoad { get; set; }

    /// <summary>Copied from the load so a student's changes for a term are one query.</summary>
    public Guid UserID { get; set; }
    public Guid TermID { get; set; }

    /// <summary>One of <see cref="StudyLoadChangeKinds"/>.</summary>
    [MaxLength(20)]
    public required string Kind { get; set; }

    [MaxLength(500)]
    public string? Reason { get; set; }

    public Guid? ChangedByUserID { get; set; }
    public DateTime ChangedAt { get; set; }
}

public static class StudyLoadChangeKinds
{
    public const string Added = "Added";
    public const string Dropped = "Dropped";
    public const string Withdrawn = "Withdrawn";
    public const string Reenrolled = "Re-enrolled";
}
