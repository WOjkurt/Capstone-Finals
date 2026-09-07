using Api.DTOs.Grading;

namespace Api.Services;

public interface IGradeCorrectionService
{
    Task<GradeCorrectionResponseDto> RequestCorrectionAsync(CreateGradeCorrectionDto dto, Guid authenticatedUserId);
    Task<List<GradeCorrectionResponseDto>> GetPendingAsync();
    Task<GradeCorrectionResponseDto> ApproveCorrectionAsync(Guid correctionId, Guid reviewerUserId);
    Task<GradeCorrectionResponseDto> RejectCorrectionAsync(Guid correctionId, Guid reviewerUserId, string? reason);
    Task<GradeCorrectionResponseDto?> GetByIdAsync(Guid correctionId, Guid authenticatedUserId, int authenticatedUserRole);
    Task<List<GradeCorrectionResponseDto>> GetMyCorrectionsAsync(Guid teacherUserId);
}
