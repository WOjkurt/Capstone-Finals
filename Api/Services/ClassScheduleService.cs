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

        dto.Room = dto.Room.Trim();
        EnsureEndAfterStart(dto.StartTime, dto.EndTime);
        await CheckOwnOverlapAsync(dto.ClassID, dto.DaysOfWeek, dto.StartTime, dto.EndTime, excludeScheduleId: null);
        await CheckRoomConflictAsync(dto.ClassID, parentClass.TermID, dto.Room, dto.DaysOfWeek, dto.StartTime, dto.EndTime, excludeScheduleId: null);
        if (parentClass.UserID.HasValue)
        {
            await TeacherScheduleConflicts.EnsureNoConflictAsync(_context, parentClass.UserID.Value, parentClass.TermID, dto.ClassID,
                new[] { (dto.DaysOfWeek, dto.StartTime, dto.EndTime) });
        }

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

        dto.Room = dto.Room.Trim();
        EnsureEndAfterStart(dto.StartTime, dto.EndTime);
        await CheckOwnOverlapAsync(dto.ClassID, dto.DaysOfWeek, dto.StartTime, dto.EndTime, excludeScheduleId: scheduleId);
        await CheckRoomConflictAsync(dto.ClassID, parentClass.TermID, dto.Room, dto.DaysOfWeek, dto.StartTime, dto.EndTime, excludeScheduleId: scheduleId);
        if (parentClass.UserID.HasValue)
        {
            await TeacherScheduleConflicts.EnsureNoConflictAsync(_context, parentClass.UserID.Value, parentClass.TermID, dto.ClassID,
                new[] { (dto.DaysOfWeek, dto.StartTime, dto.EndTime) }, excludeScheduleId: scheduleId);
        }

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

    private static void EnsureEndAfterStart(TimeOnly startTime, TimeOnly endTime)
    {
        if (endTime <= startTime)
        {
            throw new InvalidOperationException("End time must be after start time.");
        }
    }

    /// <summary>A class cannot have two meeting times that overlap, whatever the room.</summary>
    private async Task CheckOwnOverlapAsync(
        Guid classId, string daysOfWeek, TimeOnly startTime, TimeOnly endTime, Guid? excludeScheduleId)
    {
        var newDays = ParseDays(daysOfWeek);
        if (newDays.Count == 0)
        {
            return;
        }

        var query = _context.ClassSchedules.Where(cs => cs.ClassID == classId);
        if (excludeScheduleId.HasValue)
        {
            query = query.Where(cs => cs.ScheduleID != excludeScheduleId.Value);
        }

        foreach (var existing in await query.ToListAsync())
        {
            bool daysOverlap = newDays.Overlaps(ParseDays(existing.DaysOfWeek));
            bool timeOverlap = startTime < existing.EndTime && endTime > existing.StartTime;
            if (daysOverlap && timeOverlap)
            {
                throw new InvalidOperationException(
                    $"This class already meets {existing.DaysOfWeek} " +
                    $"{existing.StartTime:HH:mm}-{existing.EndTime:HH:mm} in {existing.Room}.");
            }
        }
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

        // "R101", "r101" and " R101 " are the same room.
        var normalizedRoom = room.Trim().ToLower();
        var query = _context.ClassSchedules
            .Where(cs => classIdsInTerm.Contains(cs.ClassID) && cs.Room.Trim().ToLower() == normalizedRoom);

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
