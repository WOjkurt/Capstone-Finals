using Api.Domain.Grading;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class GradeRepository : IGradeRepository
{
    private readonly AppDbContext _context;

    public GradeRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Grade?> GetByIdAsync(Guid gradeId)
    {
        return await _context.Grades
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.User)
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.Class)
                    .ThenInclude(c => c!.Subject)
            .Include(g => g.SubmittedByUser)
            .FirstOrDefaultAsync(g => g.GradeID == gradeId);
    }

    public async Task<Grade?> GetByStudyLoadIdAsync(Guid studyLoadId)
    {
        return await _context.Grades
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.User)
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.Class)
                    .ThenInclude(c => c!.Subject)
            .Include(g => g.SubmittedByUser)
            .FirstOrDefaultAsync(g => g.StudyLoadID == studyLoadId);
    }

    public async Task<List<Grade>> GetByTeacherUserIdAsync(Guid userId)
    {
        return await _context.Grades
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.User)
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.Class)
                    .ThenInclude(c => c!.Subject)
            .Include(g => g.SubmittedByUser)
            .Where(g => g.SubmittedByUserID == userId)
            .ToListAsync();
    }

    public async Task AddAsync(Grade grade)
    {
        await _context.Grades.AddAsync(grade);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(Grade grade)
    {
        _context.Grades.Update(grade);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid gradeId)
    {
        var grade = await _context.Grades.FindAsync(gradeId);
        if (grade != null)
        {
            _context.Grades.Remove(grade);
            await _context.SaveChangesAsync();
        }
    }
}
