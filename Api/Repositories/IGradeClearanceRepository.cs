using Api.Domain.Grading;

namespace Api.Repositories;

public interface IGradeClearanceRepository
{
    Task<GradeClearance?> GetByUserAndTermAsync(Guid userId, Guid termId);
    Task<List<GradeClearance>> GetByUserAsync(Guid userId);
    Task AddAsync(GradeClearance clearance);
    Task UpdateAsync(GradeClearance clearance);
}
