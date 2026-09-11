using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class ClassScheduleRepository : IClassScheduleRepository
{
    private readonly AppDbContext _context;

    public ClassScheduleRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ClassSchedule?> GetByIdAsync(Guid scheduleId)
    {
        return await _context.ClassSchedules
            .Include(cs => cs.Class)
                .ThenInclude(c => c!.Subject)
            .FirstOrDefaultAsync(cs => cs.ScheduleID == scheduleId);
    }

    public async Task<List<ClassSchedule>> GetByClassIdAsync(Guid classId)
    {
        return await _context.ClassSchedules
            .Include(cs => cs.Class)
            .Where(cs => cs.ClassID == classId)
            .ToListAsync();
    }

    public async Task<List<ClassSchedule>> GetAllAsync()
    {
        return await _context.ClassSchedules
            .Include(cs => cs.Class)
            .ToListAsync();
    }

    public async Task AddAsync(ClassSchedule schedule)
    {
        await _context.ClassSchedules.AddAsync(schedule);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(ClassSchedule schedule)
    {
        _context.ClassSchedules.Update(schedule);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid scheduleId)
    {
        var schedule = await _context.ClassSchedules.FindAsync(scheduleId);
        if (schedule != null)
        {
            _context.ClassSchedules.Remove(schedule);
            await _context.SaveChangesAsync();
        }
    }
}
