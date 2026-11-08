using System.ComponentModel.DataAnnotations;
using Api.Domain.Enrollment;

namespace Api.DTOs.Holds;

public class EnrollmentHoldDto
{
    public Guid HoldId { get; set; }
    public Guid UserId { get; set; }
    public required string Reason { get; set; }
    public required string ReasonLabel { get; set; }
    public string? Note { get; set; }
    public DateTime AddedAt { get; set; }
    public string? AddedByName { get; set; }
    public DateTime? RemovedAt { get; set; }
    public string? RemovedByName { get; set; }
    public string? RemovalNote { get; set; }
    public bool IsOpen { get; set; }
}

public class AddEnrollmentHoldDto : IValidatableObject
{
    /// <summary>"UnpaidBalance" or "Other".</summary>
    [Required]
    public required string Reason { get; set; }

    [StringLength(500)]
    public string? Note { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (!EnrollmentHoldReasons.All.Contains(Reason))
            yield return new ValidationResult("Reason must be UnpaidBalance or Other.", [nameof(Reason)]);
        else if (Reason == EnrollmentHoldReasons.Other && string.IsNullOrWhiteSpace(Note))
            yield return new ValidationResult("Write what the hold is for.", [nameof(Note)]);
    }
}

public class RemoveEnrollmentHoldDto
{
    /// <summary>For example "Paid on Nov 20, OR #12345".</summary>
    [StringLength(500)]
    public string? Note { get; set; }
}
