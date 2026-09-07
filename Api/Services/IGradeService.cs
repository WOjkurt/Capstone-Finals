using Api.DTOs.Grading;

namespace Api.Services;

public interface IGradeService
{
    Task<GradeResponseDto> SubmitGradeAsync(SubmitGradeDto dto, Guid authenticatedUserId);
    Task<GradeResponseDto?> GetByStudyLoadIdAsync(Guid studyLoadId);
    Task<List<GradeResponseDto>> GetByClassIdAsync(Guid classId, Guid authenticatedUserId, int authenticatedUserRole);
    Task<List<GradeResponseDto>> GetByStudentIdAsync(Guid userId, Guid? termId, Guid authenticatedUserId, int authenticatedUserRole);
}
