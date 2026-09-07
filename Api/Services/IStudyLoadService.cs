using Api.DTOs.StudyLoad;

namespace Api.Services;

public interface IStudyLoadService
{
    Task<List<ProposedBlockItemDto>> GetProposedBlockAsync(Guid userId, Guid termId);
    Task<List<StudyLoadResponseDto>> EnrollBatchAsync(EnrollBatchRequestDto dto, Guid createdByUserId);
    Task<EnrollSingleResponseDto> EnrollSingleAsync(EnrollSingleRequestDto dto, Guid createdByUserId);
    Task<StudyLoadResponseDto> UpdateStatusAsync(Guid studyLoadId, int newStatus);
    Task<List<StudyLoadResponseDto>> GetByStudentAsync(Guid userId, Guid termId);
    Task<List<StudyLoadResponseDto>> GetByClassAsync(Guid classId);
}
