using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface IAcademicTermRepository
{
    Task<AcademicTerm?> GetByIdAsync(Guid termId);
    Task<List<AcademicTerm>> GetAllAsync();
    Task AddAsync(AcademicTerm term);
    Task UpdateAsync(AcademicTerm term);
    Task DeleteAsync(Guid termId);
}
