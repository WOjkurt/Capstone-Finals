using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;

namespace Api.Domain.Enrollment;

/// <summary>
/// Something that stops a student from enrolling online until the Registrar removes it, such as an unpaid
/// balance (the system does not track payments, so the Registrar marks it). Removed holds are kept as history.
/// </summary>
public class EnrollmentHold
{
    [Key]
    public Guid HoldID { get; set; }

    public Guid UserID { get; set; }
    public User? User { get; set; }

    /// <summary>One of <see cref="EnrollmentHoldReasons"/>.</summary>
    [MaxLength(30)]
    public required string Reason { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }

    public Guid AddedByUserID { get; set; }
    public DateTime AddedAt { get; set; }

    public Guid? RemovedByUserID { get; set; }
    public DateTime? RemovedAt { get; set; }

    [MaxLength(500)]
    public string? RemovalNote { get; set; }

    public bool IsOpen => RemovedAt == null;
}

public static class EnrollmentHoldReasons
{
    public const string UnpaidBalance = "UnpaidBalance";
    public const string Other = "Other";

    public static readonly string[] All = { UnpaidBalance, Other };

    public static string Label(string reason) => reason switch
    {
        UnpaidBalance => "Unpaid balance",
        _ => "Other",
    };
}
