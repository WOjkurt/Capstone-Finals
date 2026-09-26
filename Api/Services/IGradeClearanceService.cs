using Api.DTOs.Grading;

namespace Api.Services;

public interface IGradeClearanceService
{
    Task<GradeClearanceResponseDto> SetClearanceAsync(Guid userId, Guid termId, bool isCleared, Guid reviewerUserId);
    Task<GradeClearanceResponseDto> CreateClearanceAsync(Guid userId, Guid termId, bool isCleared, Guid creatorUserId);
    Task EnsureClearanceAsync(Guid userId, Guid termId);
    Task<bool> IsClearedAsync(Guid userId, Guid termId);
    Task<List<GradeClearanceResponseDto>> GetByStudentAsync(Guid userId);
}
