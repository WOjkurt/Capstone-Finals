using Api.Domain.Grading;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class GradeClearanceRepository : IGradeClearanceRepository
{
    private readonly AppDbContext _context;

    public GradeClearanceRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<GradeClearance?> GetByUserAndTermAsync(Guid userId, Guid termId)
    {
        return await _context.GradeClearances
            .Include(gc => gc.Term)
            .Include(gc => gc.ClearedByUser)
            .FirstOrDefaultAsync(gc => gc.UserID == userId && gc.TermID == termId);
    }

    public async Task<List<GradeClearance>> GetByUserAsync(Guid userId)
    {
        return await _context.GradeClearances
            .Include(gc => gc.Term)
            .Include(gc => gc.ClearedByUser)
            .Where(gc => gc.UserID == userId)
            .OrderBy(gc => gc.Term != null ? gc.Term.SchoolYear : "")
            .ThenBy(gc => gc.Term != null ? gc.Term.Semester : 0)
            .ToListAsync();
    }

    public async Task AddAsync(GradeClearance clearance)
    {
        await _context.GradeClearances.AddAsync(clearance);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(GradeClearance clearance)
    {
        _context.GradeClearances.Update(clearance);
        await _context.SaveChangesAsync();
    }
}
