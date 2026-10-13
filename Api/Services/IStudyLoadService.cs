using Api.DTOs.StudyLoad;

namespace Api.Services;

public interface IStudyLoadService
{
    Task<List<ProposedBlockItemDto>> GetProposedBlockAsync(Guid userId, Guid termId);
    Task<List<EnrollBatchResponseDto>> EnrollBatchAsync(EnrollBatchRequestDto dto, Guid createdByUserId);
    Task<EnrollSingleResponseDto> EnrollSingleAsync(EnrollSingleRequestDto dto, Guid createdByUserId);
    Task<List<EnrollmentValidationFinding>> ValidateEnrollmentRulesAsync(Guid userId, Guid classId, Guid termId);
    Task<StudyLoadResponseDto> UpdateStatusAsync(Guid studyLoadId, int newStatus, int? callerRole = null);
    Task<List<StudyLoadResponseDto>> GetByStudentAsync(Guid userId, Guid termId, bool isStudentCaller = false, int? callerRole = null);
    Task<List<StudyLoadResponseDto>> GetByClassAsync(Guid classId, bool excludePending = false, int? callerRole = null);
}
