using Api.DTOs.Enrollment;

namespace Api.Services;

public interface IEnrollmentService
{
    Task<Guid> CreateResponseAsync(CreateEnrollmentResponseDto dto);
    Task<List<EnrollmentResponseDto>> GetUnprocessedResponsesAsync();
    Task<EnrollmentResponseDto?> GetResponseByIdAsync(Guid responseId);
    Task<Guid> CreateApplicationAsync(CreateEnrollmentApplicationDto dto, Guid createdByUserId);
    Task ApproveApplicationAsync(Guid applicationId, Guid reviewedByUserId, int? yearLevelOverride = null);
    Task RejectApplicationAsync(Guid applicationId, Guid reviewedByUserId, string? reason);
    Task<EnrollmentApplicationResponseDto> LinkAccountAsync(Guid applicationId, string email, Guid reviewedByUserId);
    Task<EnrollmentApplicationResponseDto?> GetApplicationByIdAsync(Guid applicationId);
    /// <summary>The student's newest application that has an enrollment form (null when none).</summary>
    Task<EnrollmentApplicationResponseDto?> GetLatestFormForStudentAsync(Guid studentUserId);
    Task<List<EnrollmentApplicationResponseDto>> GetApprovedApplicationsAsync();
    Task<List<EnrollmentApplicationResponseDto>> GetApplicationsAsync(int? status = null);
    Task<EnrollmentApplicationResponseDto> UpdateApplicationLrnAsync(Guid applicationId, string? rawLrn);
    Task<EnrollmentApplicationResponseDto> UpdateSchoolEmailAsync(Guid applicationId, string? rawSchoolEmail, Guid callerUserId);
}
