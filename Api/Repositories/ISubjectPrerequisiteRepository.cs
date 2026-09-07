using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface ISubjectPrerequisiteRepository
{
    Task<SubjectPrerequisite?> GetByIdAsync(Guid prerequisiteId);
    Task<List<SubjectPrerequisite>> GetBySubjectIdAsync(Guid subjectId);
    Task<List<SubjectPrerequisite>> GetAllAsync();
    Task AddAsync(SubjectPrerequisite prerequisite);
    Task UpdateAsync(SubjectPrerequisite prerequisite);
    Task DeleteAsync(Guid prerequisiteId);
}
