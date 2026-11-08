using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Setup;

/// <summary>The days old students can enroll online for a term. Send both empty to close enrollment.</summary>
public class SetEnrollmentPeriodDto : IValidatableObject
{
    public DateOnly? OpensOn { get; set; }
    public DateOnly? ClosesOn { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (OpensOn.HasValue != ClosesOn.HasValue)
        {
            yield return new ValidationResult("Set both the start and end dates, or leave both empty to close enrollment.",
                [nameof(OpensOn), nameof(ClosesOn)]);
        }
        else if (OpensOn > ClosesOn)
        {
            yield return new ValidationResult("The end date cannot be before the start date.", [nameof(ClosesOn)]);
        }
    }
}
