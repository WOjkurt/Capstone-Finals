using Api.Domain.IdentityAccess;

namespace Api.Repositories;

public interface IUserDetailsRepository
{
    Task<UserDetails?> GetByIdAsync(Guid userDetailId);
    Task<UserDetails?> GetByUserIdAsync(Guid userId);
    Task<UserDetails?> GetByLrnAsync(string lrn);
    Task<List<UserDetails>> GetAllAsync();
    Task<List<UserDetails>> SearchAsync(string? search, int? role, int limit = 50);
    Task AddAsync(UserDetails userDetails);
    Task UpdateAsync(UserDetails userDetails);
    Task DeleteAsync(Guid userDetailId);
}
