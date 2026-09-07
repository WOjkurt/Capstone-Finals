using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface IClassRepository
{
    Task<Class?> GetByIdAsync(Guid classId);
    Task<List<Class>> GetAllAsync();
    Task<List<Class>> GetByTermIdAsync(Guid termId);
    Task<List<Class>> GetByTeacherUserIdAsync(Guid userId);
    Task AddAsync(Class entity);
    Task UpdateAsync(Class entity);
    Task DeleteAsync(Guid classId);
}
