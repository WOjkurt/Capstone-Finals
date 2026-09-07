using Api.Domain.Grading;

namespace Api.Repositories;

public interface IGradeRepository
{
    Task<Grade?> GetByIdAsync(Guid gradeId);
    Task<Grade?> GetByStudyLoadIdAsync(Guid studyLoadId);
    Task<List<Grade>> GetByTeacherUserIdAsync(Guid userId);
    Task AddAsync(Grade grade);
    Task UpdateAsync(Grade grade);
    Task DeleteAsync(Guid gradeId);
}
