using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface IClassScheduleRepository
{
    Task<ClassSchedule?> GetByIdAsync(Guid scheduleId);
    Task<List<ClassSchedule>> GetByClassIdAsync(Guid classId);
    Task<List<ClassSchedule>> GetAllAsync();
    Task AddAsync(ClassSchedule schedule);
    Task UpdateAsync(ClassSchedule schedule);
    Task DeleteAsync(Guid scheduleId);
}
