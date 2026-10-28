using Api.Auth;
using Api.Common;
using Api.Domain.Enrollment;
using Api.DTOs.Class;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Api.Services;

public class ClassService : IClassService
{
    private readonly AppDbContext _context;
    private readonly IClassRepository _classRepository;
    private readonly IClassScheduleRepository _scheduleRepository;
    private readonly ILogger<ClassService> _logger;

    public ClassService(
        AppDbContext context,
        IClassRepository classRepository,
        IClassScheduleRepository scheduleRepository,
        ILogger<ClassService>? logger = null)
    {
        _context = context;
        _classRepository = classRepository;
        _scheduleRepository = scheduleRepository;
        _logger = logger ?? Microsoft.Extensions.Logging.Abstractions.NullLogger<ClassService>.Instance;
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

    public async Task<List<ClassDto>> GetAllAsync(Guid? termId = null, Guid? subjectId = null, Guid? teacherUserId = null, int? programId = null, Guid? studentUserId = null, int? yearLevel = null)
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

        if (studentUserId.HasValue)
        {
            var studentClassIds = _context.StudyLoads
                .Where(sl => sl.UserID == studentUserId.Value)
                .Select(sl => sl.ClassID);
            query = query.Where(c => studentClassIds.Contains(c.ClassID));
        }

        if (yearLevel.HasValue)
        {
            query = query.Where(c => c.Subject != null && c.Subject.YearLevel == yearLevel.Value);
        }

        var classes = await query.ToListAsync();
        var classIds = classes.Select(c => c.ClassID).ToList();

        var allSchedules = await _context.ClassSchedules
            .Where(cs => classIds.Contains(cs.ClassID))
            .ToListAsync();

        var scheduleMap = allSchedules
            .GroupBy(cs => cs.ClassID)
            .ToDictionary(g => g.Key, g => g.ToList());

        var enrollmentCounts = await _context.StudyLoads
            .Where(sl => classIds.Contains(sl.ClassID) && sl.LoadStatus == StudyLoadStatus.Enrolled)
            .GroupBy(sl => sl.ClassID)
            .Select(g => new { ClassId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.ClassId, x => x.Count);

        var result = new List<ClassDto>();
        foreach (var c in classes)
        {
            scheduleMap.TryGetValue(c.ClassID, out var schedules);
            enrollmentCounts.TryGetValue(c.ClassID, out var enrolledCount);
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

            result.Add(MapToDto(c, schedules ?? new List<ClassSchedule>(), teacherName, enrolledCount));
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
        int enrolledCount = await _context.StudyLoads.CountAsync(sl => sl.ClassID == classId && sl.LoadStatus == StudyLoadStatus.Enrolled);

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

        return MapToDto(entity, schedules, teacherName, enrolledCount);
    }

    public async Task<bool> CanAccessClassAsync(Guid classId, Guid userId, int role)
    {
        if (role == RoleUtils.Admin || role == RoleUtils.Registrar || role == RoleUtils.CollegeHead)
        {
            return true;
        }

        if (role == RoleUtils.Teacher)
        {
            return await _context.Classes.AnyAsync(c => c.ClassID == classId && c.UserID == userId);
        }

        if (role == RoleUtils.Student)
        {
            return await _context.StudyLoads.AnyAsync(sl => sl.ClassID == classId && sl.UserID == userId);
        }

        if (role == RoleUtils.ProgramHead)
        {
            var isTeacher = await _context.Classes.AnyAsync(c => c.ClassID == classId && c.UserID == userId);
            if (isTeacher)
            {
                return true;
            }

            var programId = await _context.UserDetails
                .Where(u => u.UserID == userId)
                .Select(u => u.ProgramID)
                .FirstOrDefaultAsync();

            if (!programId.HasValue)
            {
                return false;
            }

            return await _context.Classes
                .AnyAsync(c => c.ClassID == classId && c.Subject != null && c.Subject.ProgramID == programId.Value);
        }

        return false;
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
        int enrolledCount = await _context.StudyLoads.CountAsync(sl => sl.ClassID == classId && sl.LoadStatus == StudyLoadStatus.Enrolled);

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

        return MapToDto(entity, schedules, teacherName, enrolledCount);
    }

    public async Task<ClassDto> AssignTeacherAsync(Guid classId, Guid? userId)
    {
        var entity = await _classRepository.GetByIdAsync(classId);
        if (entity == null)
        {
            throw new KeyNotFoundException($"Class with ID '{classId}' was not found.");
        }

        entity.UserID = userId;

        await _classRepository.UpdateAsync(entity);

        var schedules = await _scheduleRepository.GetByClassIdAsync(classId);
        int enrolledCount = await _context.StudyLoads.CountAsync(sl => sl.ClassID == classId && sl.LoadStatus == StudyLoadStatus.Enrolled);

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

        return MapToDto(entity, schedules, teacherName, enrolledCount);
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

    private static ClassDto MapToDto(Class entity, List<ClassSchedule> schedules, string? teacherName = null, int enrolledCount = 0)
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
            EnrolledCount = enrolledCount,
            YearLevel = entity.Subject?.YearLevel,
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

    // ─────────────────────────────────────────────────────────────────────────
    // Bulk: Open classes for an entire term
    // ─────────────────────────────────────────────────────────────────────────

    public async Task<OpenTermResultDto> OpenTermAsync(OpenTermRequestDto request, bool dryRun, Guid callerUserId)
    {
        const int MaxClasses = 500;
        const int SampleLimit = 50;

        // ── Validate sections range ─────────────────────────────────────────
        if (request.Sections < 1 || request.Sections > 6)
        {
            throw new ArgumentOutOfRangeException(nameof(request.Sections),
                "Sections must be between 1 and 6.");
        }

        // ── Resolve program ─────────────────────────────────────────────────
        var program = await _context.AcademicPrograms.FindAsync(request.ProgramId);
        if (program == null)
        {
            throw new KeyNotFoundException(
                $"Academic program with ID {request.ProgramId} was not found.");
        }

        // ── Resolve term ────────────────────────────────────────────────────
        var term = await _context.AcademicTerms.FindAsync(request.TermId);
        if (term == null)
        {
            throw new KeyNotFoundException(
                $"Academic term with ID '{request.TermId}' was not found.");
        }

        // ── Fetch subjects in this program (optionally filtered by year level)
        var subjectsQuery = _context.Subjects
            .Where(s => s.ProgramID == request.ProgramId);

        if (request.YearLevel.HasValue)
        {
            subjectsQuery = subjectsQuery.Where(s => s.YearLevel == request.YearLevel.Value);
        }

        var allSubjects = await subjectsQuery.AsNoTracking().ToListAsync();

        // ── Split: no-default-semester subjects are always skipped ──────────
        // DefaultSemester == 0 means not set
        var toProcess = allSubjects.Where(s => s.DefaultSemester != 0).ToList();
        var noSemesterSubjects = allSubjects.Where(s => s.DefaultSemester == 0).ToList();

        // ── Filter by matching semester ──────────────────────────────────────
        toProcess = toProcess.Where(s => s.DefaultSemester == term.Semester).ToList();
        // Subjects with a non-zero DefaultSemester that don't match the term's semester
        // are neither processed nor counted as skipped-no-semester — they simply
        // don't belong to this term. Only subjects with DefaultSemester == 0 are skipped.

        // ── Safety limit check ──────────────────────────────────────────────
        int totalWouldCreate = toProcess.Count * request.Sections;
        if (totalWouldCreate > MaxClasses)
        {
            throw new InvalidOperationException(
                $"This request would create {totalWouldCreate} classes, which exceeds the safety limit of {MaxClasses}. " +
                $"Reduce the scope by filtering by year level or reducing sections.");
        }

        // ── Build section letters A, B, C… ──────────────────────────────────
        var sectionLetters = Enumerable.Range(0, request.Sections)
            .Select(i => ((char)('A' + i)).ToString())
            .ToArray();

        // ── Load existing class names for this term to check idempotency ─────
        var existingNamesInTerm = await _context.Classes
            .Where(c => c.TermID == request.TermId)
            .Select(c => new { c.SubjectID, c.ClassName })
            .AsNoTracking()
            .ToListAsync();

        var existingSet = existingNamesInTerm
            .Select(x => (x.SubjectID, x.ClassName))
            .ToHashSet();

        // ── Build plan ──────────────────────────────────────────────────────
        var toCreate = new List<(Subject subject, string className)>();
        int totalSkippedExisting = 0;

        foreach (var subject in toProcess)
        {
            foreach (var section in sectionLetters)
            {
                var className = ClassNameHelper.Format(program.ProgramCode, subject.YearLevel, section);

                if (existingSet.Contains((subject.SubjectID, className)))
                {
                    totalSkippedExisting++;
                }
                else
                {
                    toCreate.Add((subject, className));
                }
            }
        }

        int totalSkippedNoSem = noSemesterSubjects.Count;

        // Sample class names (first 50 from toCreate)
        var sampleNames = toCreate
            .Take(SampleLimit)
            .Select(x => x.className)
            .ToList();

        // perYear: year level -> count of classes
        var perYear = toCreate
            .GroupBy(x => x.subject.YearLevel)
            .OrderBy(g => g.Key)
            .ToDictionary(g => g.Key, g => g.Count());

        // ── Dry run: return plan without writing ─────────────────────────────
        if (dryRun)
        {
            return new OpenTermResultDto
            {
                DryRun = true,
                TermId = request.TermId,
                ProgramId = request.ProgramId,
                PlannedCount = toCreate.Count,
                CreatedCount = 0,
                SkippedExisting = totalSkippedExisting,
                SkippedNoDefaultSemester = totalSkippedNoSem,
                PerYear = perYear,
                TermIsActive = term.IsActive,
                SampleClassNames = sampleNames
            };
        }

        // ── Real run: create inside a transaction ────────────────────────────
        int created = 0;
        using var txn = await _context.Database.BeginTransactionAsync();
        try
        {
            foreach (var (subject, className) in toCreate)
            {
                var entity = new Class
                {
                    ClassID = Guid.NewGuid(),
                    SubjectID = subject.SubjectID,
                    UserID = null,
                    TermID = request.TermId,
                    ClassName = className,
                    CreatedAt = DateTime.UtcNow,
                    CreatedByUserID = callerUserId
                };
                _context.Classes.Add(entity);
                created++;
            }

            await _context.SaveChangesAsync();
            await txn.CommitAsync();
        }
        catch
        {
            await txn.RollbackAsync();
            throw;
        }

        // ── Audit log ────────────────────────────────────────────────────────
        var termLabel = TermLabel.Format(term.SchoolYear, term.Semester);
        _logger.LogInformation(
            "BulkOpenTerm: callerUserId={CallerUserId} program={ProgramCode} ({ProgramId}) " +
            "term={TermLabel} ({TermId}) created={Created} skippedExisting={SkippedExisting} " +
            "skippedNoSemester={SkippedNoSemester}",
            callerUserId, program.ProgramCode, request.ProgramId,
            termLabel, request.TermId,
            created, totalSkippedExisting, totalSkippedNoSem);

        return new OpenTermResultDto
        {
            DryRun = false,
            TermId = request.TermId,
            ProgramId = request.ProgramId,
            PlannedCount = toCreate.Count,
            CreatedCount = created,
            SkippedExisting = totalSkippedExisting,
            SkippedNoDefaultSemester = totalSkippedNoSem,
            PerYear = perYear,
            TermIsActive = term.IsActive,
            SampleClassNames = sampleNames
        };
    }
}
