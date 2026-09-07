using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class ClassRepository : IClassRepository
{
    private readonly AppDbContext _context;

    public ClassRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Class?> GetByIdAsync(Guid classId)
    {
        return await _context.Classes
            .Include(c => c.Subject)
            .Include(c => c.User)
            .Include(c => c.Term)
            .FirstOrDefaultAsync(c => c.ClassID == classId);
    }

    public async Task<List<Class>> GetAllAsync()
    {
        return await _context.Classes
            .Include(c => c.Subject)
            .Include(c => c.User)
            .Include(c => c.Term)
            .ToListAsync();
    }

    public async Task<List<Class>> GetByTermIdAsync(Guid termId)
    {
        return await _context.Classes
            .Include(c => c.Subject)
            .Include(c => c.User)
            .Include(c => c.Term)
            .Where(c => c.TermID == termId)
            .ToListAsync();
    }

    public async Task<List<Class>> GetByTeacherUserIdAsync(Guid userId)
    {
        return await _context.Classes
            .Include(c => c.Subject)
            .Include(c => c.User)
            .Include(c => c.Term)
            .Where(c => c.UserID == userId)
            .ToListAsync();
    }

    public async Task AddAsync(Class entity)
    {
        await _context.Classes.AddAsync(entity);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(Class entity)
    {
        _context.Classes.Update(entity);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid classId)
    {
        var entity = await _context.Classes.FindAsync(classId);
        if (entity != null)
        {
            _context.Classes.Remove(entity);
            await _context.SaveChangesAsync();
        }
    }
}
