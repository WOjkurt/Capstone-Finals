using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;

namespace Api.Domain.Enrollment;

/// <summary>
/// Personal details the Registrar keeps for the student's records (Transcript of Records).
/// Each empty field falls back to the student's enrollment form, so this only needs what the form lacks or got wrong.
/// </summary>
public class StudentPersonalDetails
{
    [Key]
    public Guid UserID { get; set; }
    public User? User { get; set; }

    [MaxLength(100)]
    public string? MiddleName { get; set; }

    [MaxLength(20)]
    public string? Suffix { get; set; }

    [MaxLength(300)]
    public string? Address { get; set; }

    public DateOnly? DateOfBirth { get; set; }

    [MaxLength(150)]
    public string? PlaceOfBirth { get; set; }

    [MaxLength(20)]
    public string? Sex { get; set; }

    [MaxLength(60)]
    public string? Nationality { get; set; }

    /// <summary>Last school attended before DBTC.</summary>
    [MaxLength(200)]
    public string? EntranceData { get; set; }

    /// <summary>As printed, e.g. "1st Semester, 2024-2025". Empty means the first term the student was enrolled in.</summary>
    [MaxLength(60)]
    public string? DateAdmitted { get; set; }

    public Guid UpdatedByUserID { get; set; }
    public User? UpdatedByUser { get; set; }

    public DateTime UpdatedAt { get; set; }
}
