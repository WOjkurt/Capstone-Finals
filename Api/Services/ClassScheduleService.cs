using Api.Domain.Enrollment;
using Api.DTOs.Class;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public class ClassScheduleService : IClassScheduleService
{
    private readonly AppDbContext _context;
    private readonly IClassScheduleRepository _scheduleRepository;
    private readonly IClassRepository _classRepository;

    public ClassScheduleService(
        AppDbContext context,
        IClassScheduleRepository scheduleRepository,
        IClassRepository classRepository)
    {
        _context = context;
        _scheduleRepository = scheduleRepository;
        _classRepository = classRepository;
    }

    public async Task<ClassScheduleDto> CreateAsync(CreateClassScheduleDto dto)
    {
        var parentClass = await _classRepository.GetByIdAsync(dto.ClassID);
        if (parentClass == null)
        {
            throw new KeyNotFoundException($"Class with ID '{dto.ClassID}' was not found.");
        }

        await CheckRoomConflictAsync(dto.ClassID, parentClass.TermID, dto.Room, dto.DaysOfWeek, dto.StartTime, dto.EndTime, excludeScheduleId: null);

        var schedule = new ClassSchedule
        {
            ScheduleID = Guid.NewGuid(),
            ClassID = dto.ClassID,
            DaysOfWeek = dto.DaysOfWeek,
            StartTime = dto.StartTime,
            EndTime = dto.EndTime,
            Room = dto.Room
        };

        await _scheduleRepository.AddAsync(schedule);

        return MapToDto(schedule);
    }

    public async Task<List<ClassScheduleDto>> GetByClassIdAsync(Guid classId)
    {
        var schedules = await _scheduleRepository.GetByClassIdAsync(classId);
        return schedules.Select(MapToDto).ToList();
    }

    public async Task<ClassScheduleDto> UpdateAsync(Guid scheduleId, CreateClassScheduleDto dto)
    {
        var schedule = await _scheduleRepository.GetByIdAsync(scheduleId);
        if (schedule == null)
        {
            throw new KeyNotFoundException($"ClassSchedule with ID '{scheduleId}' was not found.");
        }

        var parentClass = await _classRepository.GetByIdAsync(dto.ClassID);
        if (parentClass == null)
        {
            throw new KeyNotFoundException($"Class with ID '{dto.ClassID}' was not found.");
        }

        await CheckRoomConflictAsync(dto.ClassID, parentClass.TermID, dto.Room, dto.DaysOfWeek, dto.StartTime, dto.EndTime, excludeScheduleId: scheduleId);

        schedule.ClassID = dto.ClassID;
        schedule.DaysOfWeek = dto.DaysOfWeek;
        schedule.StartTime = dto.StartTime;
        schedule.EndTime = dto.EndTime;
        schedule.Room = dto.Room;

        await _scheduleRepository.UpdateAsync(schedule);

        return MapToDto(schedule);
    }

    public async Task DeleteAsync(Guid scheduleId)
    {
        var schedule = await _scheduleRepository.GetByIdAsync(scheduleId);
        if (schedule == null)
        {
            throw new KeyNotFoundException($"ClassSchedule with ID '{scheduleId}' was not found.");
        }

        await _scheduleRepository.DeleteAsync(scheduleId);
    }

    private async Task CheckRoomConflictAsync(
        Guid classId, Guid termId, string room, string daysOfWeek,
        TimeOnly startTime, TimeOnly endTime, Guid? excludeScheduleId)
    {
        var newDays = ParseDays(daysOfWeek);
        if (newDays.Count == 0)
        {
            return;
        }

        var classIdsInTerm = await _context.Classes
            .Where(c => c.TermID == termId && c.ClassID != classId)
            .Select(c => c.ClassID)
            .ToListAsync();

        if (classIdsInTerm.Count == 0)
        {
            return;
        }

        var query = _context.ClassSchedules
            .Where(cs => classIdsInTerm.Contains(cs.ClassID) && cs.Room == room);

        if (excludeScheduleId.HasValue)
        {
            query = query.Where(cs => cs.ScheduleID != excludeScheduleId.Value);
        }

        var sameRoomSchedules = await query.ToListAsync();

        foreach (var existing in sameRoomSchedules)
        {
            var existingDays = ParseDays(existing.DaysOfWeek);
            bool daysOverlap = newDays.Intersect(existingDays).Any();

            if (!daysOverlap)
            {
                continue;
            }

            bool timeOverlap = startTime < existing.EndTime && endTime > existing.StartTime;

            if (timeOverlap)
            {
                throw new InvalidOperationException(
                    $"Room '{room}' is already booked {existing.DaysOfWeek} " +
                    $"{existing.StartTime:HH:mm}-{existing.EndTime:HH:mm} " +
                    $"for another class this term.");
            }
        }
    }

    private static HashSet<string> ParseDays(string daysOfWeek)
    {
        return daysOfWeek
            .Split(new[] { '/', ',', ' ' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(d => d.ToUpperInvariant())
            .ToHashSet();
    }

    private static ClassScheduleDto MapToDto(ClassSchedule schedule)
    {
        return new ClassScheduleDto
        {
            ScheduleID = schedule.ScheduleID,
            ClassID = schedule.ClassID,
            DaysOfWeek = schedule.DaysOfWeek,
            StartTime = schedule.StartTime,
            EndTime = schedule.EndTime,
            Room = schedule.Room
        };
    }
}
