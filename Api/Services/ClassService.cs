using Api.Domain.Enrollment;
using Api.DTOs.Class;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public class ClassService : IClassService
{
    private readonly AppDbContext _context;
    private readonly IClassRepository _classRepository;
    private readonly IClassScheduleRepository _scheduleRepository;

    public ClassService(
        AppDbContext context,
        IClassRepository classRepository,
        IClassScheduleRepository scheduleRepository)
    {
        _context = context;
        _classRepository = classRepository;
        _scheduleRepository = scheduleRepository;
    }

    public async Task<ClassDto> CreateAsync(CreateClassDto dto, Guid createdByUserId)
    {
        var subject = await _context.Subjects.FindAsync(dto.SubjectID);
        if (subject == null)
        {
            throw new KeyNotFoundException($"Subject with ID '{dto.SubjectID}' was not found.");
        }

        var term = await _context.AcademicTerms.FindAsync(dto.TermID);
        if (term == null)
        {
            throw new KeyNotFoundException($"AcademicTerm with ID '{dto.TermID}' was not found.");
        }

        var entity = new Class
        {
            ClassID = Guid.NewGuid(),
            SubjectID = dto.SubjectID,
            UserID = dto.UserID,
            TermID = dto.TermID,
            ClassName = dto.ClassName,
            CreatedAt = DateTime.UtcNow,
            CreatedByUserID = createdByUserId
        };

        await _classRepository.AddAsync(entity);

        var created = await _classRepository.GetByIdAsync(entity.ClassID);
        return MapToDto(created!, new List<ClassSchedule>());
    }

    public async Task<List<ClassDto>> GetAllAsync(Guid? termId = null, Guid? subjectId = null, Guid? teacherUserId = null, int? programId = null)
    {
        var query = _context.Classes
            .Include(c => c.Subject)
            .Include(c => c.User)
            .Include(c => c.Term)
            .AsQueryable();

        if (termId.HasValue)
        {
            query = query.Where(c => c.TermID == termId.Value);
        }

        if (subjectId.HasValue)
        {
            query = query.Where(c => c.SubjectID == subjectId.Value);
        }

        if (teacherUserId.HasValue)
        {
            query = query.Where(c => c.UserID == teacherUserId.Value);
        }

        if (programId.HasValue)
        {
            query = query.Where(c => c.Subject != null && c.Subject.ProgramID == programId.Value);
        }

        var classes = await query.ToListAsync();
        var classIds = classes.Select(c => c.ClassID).ToList();

        var allSchedules = await _context.ClassSchedules
            .Where(cs => classIds.Contains(cs.ClassID))
            .ToListAsync();

        var scheduleMap = allSchedules
            .GroupBy(cs => cs.ClassID)
            .ToDictionary(g => g.Key, g => g.ToList());

        var result = new List<ClassDto>();
        foreach (var c in classes)
        {
            scheduleMap.TryGetValue(c.ClassID, out var schedules);
            string? teacherName = null;
            if (c.UserID.HasValue)
            {
                var ud = await _context.UserDetails
                    .AsNoTracking()
                    .FirstOrDefaultAsync(u => u.UserID == c.UserID.Value);
                if (ud != null)
                {
                    teacherName = $"{ud.Firstname} {ud.Lastname}";
                }
            }

            result.Add(MapToDto(c, schedules ?? new List<ClassSchedule>(), teacherName));
        }

        return result;
    }

    public async Task<ClassDto?> GetByIdAsync(Guid classId)
    {
        var entity = await _classRepository.GetByIdAsync(classId);
        if (entity == null)
        {
            return null;
        }

        var schedules = await _scheduleRepository.GetByClassIdAsync(classId);

        string? teacherName = null;
        if (entity.UserID.HasValue)
        {
            var ud = await _context.UserDetails
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.UserID == entity.UserID.Value);
            if (ud != null)
            {
                teacherName = $"{ud.Firstname} {ud.Lastname}";
            }
        }

        return MapToDto(entity, schedules, teacherName);
    }

    public async Task<ClassDto> UpdateAsync(Guid classId, UpdateClassDto dto)
    {
        var entity = await _classRepository.GetByIdAsync(classId);
        if (entity == null)
        {
            throw new KeyNotFoundException($"Class with ID '{classId}' was not found.");
        }

        entity.UserID = dto.UserID;
        entity.ClassName = dto.ClassName;

        await _classRepository.UpdateAsync(entity);

        var schedules = await _scheduleRepository.GetByClassIdAsync(classId);

        string? teacherName = null;
        if (entity.UserID.HasValue)
        {
            var ud = await _context.UserDetails
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.UserID == entity.UserID.Value);
            if (ud != null)
            {
                teacherName = $"{ud.Firstname} {ud.Lastname}";
            }
        }

        return MapToDto(entity, schedules, teacherName);
    }

    public async Task DeleteAsync(Guid classId)
    {
        var entity = await _classRepository.GetByIdAsync(classId);
        if (entity == null)
        {
            throw new KeyNotFoundException($"Class with ID '{classId}' was not found.");
        }

        bool hasStudyLoads = await _context.StudyLoads.AnyAsync(sl => sl.ClassID == classId);
        if (hasStudyLoads)
        {
            throw new InvalidOperationException($"Cannot delete Class '{entity.ClassName}' because it is referenced by existing study loads.");
        }

        bool hasGrades = await _context.Grades.AnyAsync(g => g.StudyLoad != null && g.StudyLoad.ClassID == classId);
        if (hasGrades)
        {
            throw new InvalidOperationException($"Cannot delete Class '{entity.ClassName}' because it is referenced by existing grades (via study loads).");
        }

        await _classRepository.DeleteAsync(classId);
    }

    private static ClassDto MapToDto(Class entity, List<ClassSchedule> schedules, string? teacherName = null)
    {
        return new ClassDto
        {
            ClassID = entity.ClassID,
            SubjectID = entity.SubjectID,
            SubjectCode = entity.Subject?.SubjectCode,
            SubjectTitle = entity.Subject?.SubjectTitle,
            UserID = entity.UserID,
            TeacherName = teacherName,
            TermID = entity.TermID,
            TermSchoolYear = entity.Term?.SchoolYear,
            TermSemester = entity.Term?.Semester,
            ClassName = entity.ClassName,
            CreatedAt = entity.CreatedAt,
            CreatedByUserID = entity.CreatedByUserID,
            Schedules = schedules.Select(s => new ClassScheduleDto
            {
                ScheduleID = s.ScheduleID,
                ClassID = s.ClassID,
                DaysOfWeek = s.DaysOfWeek,
                StartTime = s.StartTime,
                EndTime = s.EndTime,
                Room = s.Room
            }).ToList()
        };
    }
}
