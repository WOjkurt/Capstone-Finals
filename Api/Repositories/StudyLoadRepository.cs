using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class StudyLoadRepository : IStudyLoadRepository
{
    private readonly AppDbContext _context;

    public StudyLoadRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<StudyLoad?> GetByIdAsync(Guid studyLoadId)
    {
        return await _context.StudyLoads
            .Include(sl => sl.User)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Subject)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Term)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.ClassSchedules)
            .FirstOrDefaultAsync(sl => sl.StudyLoadID == studyLoadId);
    }

    public async Task<List<StudyLoad>> GetByUserIdAsync(Guid userId)
    {
        return await _context.StudyLoads
            .Include(sl => sl.User)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Subject)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Term)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.ClassSchedules)
            .Where(sl => sl.UserID == userId)
            .ToListAsync();
    }

    public async Task<List<StudyLoad>> GetByClassIdAsync(Guid classId)
    {
        return await _context.StudyLoads
            .Include(sl => sl.User)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.ClassSchedules)
            .Where(sl => sl.ClassID == classId)
            .ToListAsync();
    }

    public async Task<List<StudyLoad>> GetByUserAndTermAsync(Guid userId, Guid termId)
    {
        return await _context.StudyLoads
            .Include(sl => sl.User)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Subject)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Term)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.ClassSchedules)
            .Where(sl => sl.UserID == userId && sl.Class != null && sl.Class.TermID == termId)
            .ToListAsync();
    }

    public async Task<List<StudyLoad>> GetActiveByUserAndTermAsync(Guid userId, Guid termId)
    {
        return await _context.StudyLoads
            .Include(sl => sl.User)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Subject)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Term)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.ClassSchedules)
            .Where(sl => sl.UserID == userId && sl.LoadStatus == 1 && sl.Class != null && sl.Class.TermID == termId)
            .ToListAsync();
    }

    public async Task<StudyLoad?> GetByUserAndClassAsync(Guid userId, Guid classId)
    {
        return await _context.StudyLoads
            .Include(sl => sl.User)
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.ClassSchedules)
            .FirstOrDefaultAsync(sl => sl.UserID == userId && sl.ClassID == classId);
    }

    public async Task AddAsync(StudyLoad studyLoad)
    {
        await _context.StudyLoads.AddAsync(studyLoad);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(StudyLoad studyLoad)
    {
        _context.StudyLoads.Update(studyLoad);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid studyLoadId)
    {
        var studyLoad = await _context.StudyLoads.FindAsync(studyLoadId);
        if (studyLoad != null)
        {
            _context.StudyLoads.Remove(studyLoad);
            await _context.SaveChangesAsync();
        }
    }
}
