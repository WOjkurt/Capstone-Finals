using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface ISubjectRepository
{
    Task<Subject?> GetByIdAsync(Guid subjectId);
    Task<List<Subject>> GetAllAsync();
    Task<List<Subject>> GetByProgramIdAsync(int programId);
    Task AddAsync(Subject subject);
    Task UpdateAsync(Subject subject);
    Task DeleteAsync(Guid subjectId);
}
