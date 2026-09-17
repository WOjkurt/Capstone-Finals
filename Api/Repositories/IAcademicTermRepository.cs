using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface IAcademicTermRepository
{
    Task<AcademicTerm?> GetByIdAsync(Guid termId);
    Task<AcademicTerm?> GetActiveAsync();
    Task<List<AcademicTerm>> GetAllAsync();
    Task AddAsync(AcademicTerm term);
    Task UpdateAsync(AcademicTerm term);
    Task SetActiveAsync(Guid termId);
    Task DeleteAsync(Guid termId);
}
