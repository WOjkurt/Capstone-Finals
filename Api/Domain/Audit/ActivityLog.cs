using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Audit;

/// <summary>
/// One staff action worth tracing later: who did what, when, to which student and term.
/// Names are copied at the time of the action so the log still reads correctly if people are renamed.
/// </summary>
public class ActivityLog
{
    [Key]
    public Guid ActivityLogID { get; set; }

    public DateTime OccurredAt { get; set; }

    public Guid? ActorUserID { get; set; }

    [MaxLength(200)]
    public string ActorName { get; set; } = string.Empty;

    public int? ActorRole { get; set; }

    /// <summary>One of <see cref="ActivityActions"/>.</summary>
    [MaxLength(50)]
    public required string Action { get; set; }

    public Guid? StudentUserID { get; set; }

    [MaxLength(200)]
    public string? StudentName { get; set; }

    public Guid? TermID { get; set; }

    [MaxLength(1000)]
    public required string Summary { get; set; }
}

public static class ActivityActions
{
    public const string LoadsSaved = "LOADS_SAVED";
    public const string ForcedEnrollment = "FORCED_ENROLLMENT";
    public const string LoadsFinalized = "LOADS_FINALIZED";
    public const string LoadStatusChanged = "LOAD_STATUS_CHANGED";
    public const string OverloadApproved = "OVERLOAD_APPROVED";
    public const string YearLevelChanged = "YEAR_LEVEL_CHANGED";
    public const string CreditAdded = "CREDIT_ADDED";
    public const string CreditRemoved = "CREDIT_REMOVED";
    public const string GradeCorrectionApproved = "GRADE_CORRECTION_APPROVED";
    public const string GradeCorrectionRejected = "GRADE_CORRECTION_REJECTED";
    public const string TeacherAssigned = "TEACHER_ASSIGNED";
    public const string ClearanceChanged = "CLEARANCE_CHANGED";
    public const string PersonalDetailsUpdated = "PERSONAL_DETAILS_UPDATED";

    public static readonly string[] All =
    {
        LoadsSaved, ForcedEnrollment, LoadsFinalized, LoadStatusChanged, OverloadApproved, YearLevelChanged,
        CreditAdded, CreditRemoved, GradeCorrectionApproved, GradeCorrectionRejected, TeacherAssigned, ClearanceChanged,
        PersonalDetailsUpdated
    };
}
