using Api.DTOs.Class;

namespace Api.Services;

public interface IClassScheduleService
{
    Task<ClassScheduleDto> CreateAsync(CreateClassScheduleDto dto);
    Task<List<ClassScheduleDto>> GetByClassIdAsync(Guid classId);
    Task<ClassScheduleDto> UpdateAsync(Guid scheduleId, CreateClassScheduleDto dto);
    Task DeleteAsync(Guid scheduleId);
}
