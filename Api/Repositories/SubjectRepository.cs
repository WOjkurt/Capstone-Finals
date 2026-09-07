using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class SubjectRepository : ISubjectRepository
{
    private readonly AppDbContext _context;

    public SubjectRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Subject?> GetByIdAsync(Guid subjectId)
    {
        return await _context.Subjects
            .Include(s => s.Program)
            .FirstOrDefaultAsync(s => s.SubjectID == subjectId);
    }

    public async Task<List<Subject>> GetAllAsync()
    {
        return await _context.Subjects
            .Include(s => s.Program)
            .ToListAsync();
    }

    public async Task<List<Subject>> GetByProgramIdAsync(int programId)
    {
        return await _context.Subjects
            .Include(s => s.Program)
            .Where(s => s.ProgramID == programId)
            .ToListAsync();
    }

    public async Task AddAsync(Subject subject)
    {
        await _context.Subjects.AddAsync(subject);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(Subject subject)
    {
        _context.Subjects.Update(subject);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid subjectId)
    {
        var subject = await _context.Subjects.FindAsync(subjectId);
        if (subject != null)
        {
            _context.Subjects.Remove(subject);
            await _context.SaveChangesAsync();
        }
    }
}
