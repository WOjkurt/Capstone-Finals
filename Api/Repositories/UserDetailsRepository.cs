using Api.Domain.IdentityAccess;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class UserDetailsRepository : IUserDetailsRepository
{
    private readonly AppDbContext _context;

    public UserDetailsRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<UserDetails?> GetByIdAsync(Guid userDetailId)
    {
        return await _context.UserDetails
            .Include(ud => ud.User)
            .Include(ud => ud.Program)
            .Include(ud => ud.Position)
            .FirstOrDefaultAsync(ud => ud.UserDetailID == userDetailId);
    }

    public async Task<UserDetails?> GetByUserIdAsync(Guid userId)
    {
        return await _context.UserDetails
            .Include(ud => ud.User)
            .Include(ud => ud.Program)
            .Include(ud => ud.Position)
            .FirstOrDefaultAsync(ud => ud.UserID == userId);
    }

    public async Task<UserDetails?> GetByLrnAsync(string lrn)
    {
        return await _context.UserDetails
            .Include(ud => ud.User)
            .Include(ud => ud.Program)
            .Include(ud => ud.Position)
            .FirstOrDefaultAsync(ud => ud.LRN == lrn);
    }

    public async Task<List<UserDetails>> GetAllAsync()
    {
        return await _context.UserDetails
            .Include(ud => ud.User)
            .Include(ud => ud.Program)
            .Include(ud => ud.Position)
            .ToListAsync();
    }

    public async Task<List<UserDetails>> SearchAsync(string? search, int? role, int? programId = null, int? limit = 50)
    {
        var query = _context.UserDetails
            .AsNoTracking()
            .Include(ud => ud.User)
            .Include(ud => ud.Program)
            .AsQueryable();

        if (role.HasValue)
        {
            query = query.Where(ud => ud.User != null && ud.User.Role == role.Value);
        }

        if (programId.HasValue)
        {
            query = query.Where(ud => ud.ProgramID == programId.Value);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim()
                .Replace("\\", "\\\\")
                .Replace("%", "\\%")
                .Replace("_", "\\_");
            query = query.Where(ud =>
                EF.Functions.ILike(ud.Firstname, $"%{term}%", "\\") ||
                EF.Functions.ILike(ud.Lastname, $"%{term}%", "\\") ||
                (ud.User != null && EF.Functions.ILike(ud.User.Email, $"%{term}%", "\\"))
            );
        }

        query = query
            .OrderBy(ud => ud.Lastname)
            .ThenBy(ud => ud.Firstname);

        if (limit.HasValue)
        {
            query = query.Take(limit.Value);
        }

        return await query.ToListAsync();
    }

    public async Task AddAsync(UserDetails userDetails)
    {
        await _context.UserDetails.AddAsync(userDetails);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(UserDetails userDetails)
    {
        _context.UserDetails.Update(userDetails);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid userDetailId)
    {
        var userDetails = await _context.UserDetails.FindAsync(userDetailId);
        if (userDetails != null)
        {
            _context.UserDetails.Remove(userDetails);
            await _context.SaveChangesAsync();
        }
    }
}
