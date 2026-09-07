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
    Task<List<EnrollmentApplicationResponseDto>> GetApprovedApplicationsAsync();
    Task<List<EnrollmentApplicationResponseDto>> GetApplicationsAsync(int? status = null);
}
