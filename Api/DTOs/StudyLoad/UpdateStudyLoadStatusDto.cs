using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using Api.Domain.Enrollment;

namespace Api.DTOs.StudyLoad;

public class UpdateStudyLoadStatusDto : IValidatableObject
{
    public int LoadStatus { get; set; }

    /// <summary>Why the subject is dropped, withdrawn or re-enrolled. Required to drop or withdraw an Enrolled subject.</summary>
    [MaxLength(500)]
    public string? Reason { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (LoadStatus == StudyLoadStatus.Pending)
        {
            yield return new ValidationResult(
                "LoadStatus must be between Enrolled (1) and Withdrawn (3) or Rejected (5). Pending (4) cannot be set via this endpoint.",
                new[] { nameof(LoadStatus) });
        }
        else if (LoadStatus != StudyLoadStatus.Enrolled &&
                 LoadStatus != StudyLoadStatus.Dropped &&
                 LoadStatus != StudyLoadStatus.Withdrawn &&
                 LoadStatus != StudyLoadStatus.Rejected)
        {
            yield return new ValidationResult(
                "LoadStatus must be Enrolled (1), Dropped (2), Withdrawn (3), or Rejected (5).",
                new[] { nameof(LoadStatus) });
        }
    }
}
