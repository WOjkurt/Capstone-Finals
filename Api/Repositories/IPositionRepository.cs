using Api.Domain.IdentityAccess;

namespace Api.Repositories;

public interface IPositionRepository
{
    Task<Position?> GetByIdAsync(Guid positionId);
    Task<List<Position>> GetAllAsync();
    Task AddAsync(Position position);
    Task UpdateAsync(Position position);
    Task DeleteAsync(Guid positionId);
}
