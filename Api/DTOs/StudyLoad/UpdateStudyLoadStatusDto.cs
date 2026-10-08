using System.ComponentModel.DataAnnotations;
using Api.Domain.Enrollment;

namespace Api.DTOs.StudyLoad;

public class UpdateStudyLoadStatusDto
{
    [Range(StudyLoadStatus.Enrolled, StudyLoadStatus.Withdrawn, ErrorMessage = "LoadStatus must be between Enrolled (1) and Withdrawn (3). Pending (4) cannot be set via this endpoint.")]
    public int LoadStatus { get; set; }
}
