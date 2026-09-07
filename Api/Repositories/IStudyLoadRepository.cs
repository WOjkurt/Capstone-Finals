using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface IStudyLoadRepository
{
    Task<StudyLoad?> GetByIdAsync(Guid studyLoadId);
    Task<List<StudyLoad>> GetByUserIdAsync(Guid userId);
    Task<List<StudyLoad>> GetByClassIdAsync(Guid classId);
    Task<List<StudyLoad>> GetByUserAndTermAsync(Guid userId, Guid termId);
    Task<List<StudyLoad>> GetActiveByUserAndTermAsync(Guid userId, Guid termId);
    Task<StudyLoad?> GetByUserAndClassAsync(Guid userId, Guid classId);
    Task AddAsync(StudyLoad studyLoad);
    Task UpdateAsync(StudyLoad studyLoad);
    Task DeleteAsync(Guid studyLoadId);
}
