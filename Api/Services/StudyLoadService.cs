using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public class StudyLoadService : IStudyLoadService
{
    private readonly AppDbContext _context;
    private readonly IStudyLoadRepository _studyLoadRepository;
    private readonly IGradeClearanceService _clearanceService;

    public StudyLoadService(AppDbContext context, IStudyLoadRepository studyLoadRepository, IGradeClearanceService clearanceService)
    {
        _context = context;
        _studyLoadRepository = studyLoadRepository;
        _clearanceService = clearanceService;
    }

    public async Task<List<ProposedBlockItemDto>> GetProposedBlockAsync(Guid userId, Guid termId)
    {
        var userDetails = await _context.UserDetails
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.UserID == userId);

        if (userDetails == null)
        {
            throw new KeyNotFoundException($"UserDetails not found for user '{userId}'.");
        }

        if (!userDetails.ProgramID.HasValue || !userDetails.YearLevel.HasValue)
        {
            throw new InvalidOperationException("Cannot generate proposed block: Student's ProgramID and YearLevel must both be set.");
        }

        var term = await _context.AcademicTerms
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.TermID == termId);

        if (term == null)
        {
            throw new KeyNotFoundException($"AcademicTerm with ID '{termId}' was not found.");
        }

        var subjects = await _context.Subjects
            .AsNoTracking()
            .Where(s => s.ProgramID == userDetails.ProgramID.Value &&
                        s.YearLevel == userDetails.YearLevel.Value &&
                        s.DefaultSemester == term.Semester)
            .ToListAsync();

        var result = new List<ProposedBlockItemDto>();

        foreach (var subject in subjects)
        {
            var classes = await _context.Classes
                .AsNoTracking()
                .Include(c => c.User)
                .Where(c => c.SubjectID == subject.SubjectID && c.TermID == termId)
                .ToListAsync();

            if (classes.Count == 0)
            {
                result.Add(new ProposedBlockItemDto
                {
                    SubjectId = subject.SubjectID,
                    SubjectCode = subject.SubjectCode,
                    SubjectTitle = subject.SubjectTitle,
                    ClassId = null,
                    ClassName = null,
                    MatchType = "no_class_offered",
                    Options = null
                });
            }
            else if (classes.Count == 1)
            {
                var singleClass = classes[0];
                result.Add(new ProposedBlockItemDto
                {
                    SubjectId = subject.SubjectID,
                    SubjectCode = subject.SubjectCode,
                    SubjectTitle = subject.SubjectTitle,
                    ClassId = singleClass.ClassID,
                    ClassName = singleClass.ClassName,
                    MatchType = "auto",
                    Options = null
                });
            }
            else
            {
                var options = new List<ClassOptionDto>();
                foreach (var c in classes)
                {
                    string? teacherName = await ResolveTeacherNameAsync(c.UserID);
                    string scheduleStr = await FormatClassScheduleAsync(c.ClassID);

                    options.Add(new ClassOptionDto
                    {
                        ClassId = c.ClassID,
                        ClassName = c.ClassName,
                        TeacherName = teacherName,
                        Schedule = scheduleStr
                    });
                }

                result.Add(new ProposedBlockItemDto
                {
                    SubjectId = subject.SubjectID,
                    SubjectCode = subject.SubjectCode,
                    SubjectTitle = subject.SubjectTitle,
                    ClassId = null,
                    ClassName = null,
                    MatchType = "multiple_found",
                    Options = options
                });
            }
        }

        return result;
    }

    public async Task<List<StudyLoadResponseDto>> EnrollBatchAsync(EnrollBatchRequestDto dto, Guid createdByUserId)
    {
        var user = await _context.Users.FindAsync(dto.UserId);
        if (user == null)
        {
            throw new KeyNotFoundException($"User with ID '{dto.UserId}' was not found.");
        }

        var term = await _context.AcademicTerms.FindAsync(dto.TermId);
        if (term == null)
        {
            throw new KeyNotFoundException($"AcademicTerm with ID '{dto.TermId}' was not found.");
        }

        await ValidatePriorTermClearanceAsync(dto.UserId, dto.TermId);

        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            var resultList = new List<StudyLoadResponseDto>();

            foreach (var classId in dto.ClassIds)
            {
                var existingActive = await _studyLoadRepository.GetByUserAndClassAsync(dto.UserId, classId);
                if (existingActive != null && existingActive.LoadStatus == 1)
                {
                    // Skip creating duplicate if active study load already exists
                    var fullExisting = await _studyLoadRepository.GetByIdAsync(existingActive.StudyLoadID);
                    if (fullExisting != null)
                    {
                        resultList.Add(await MapToDtoAsync(fullExisting));
                    }
                    continue;
                }

                var targetClass = await _context.Classes
                    .Include(c => c.Subject)
                    .Include(c => c.Term)
                    .FirstOrDefaultAsync(c => c.ClassID == classId);

                if (targetClass == null)
                {
                    throw new KeyNotFoundException($"Class with ID '{classId}' was not found.");
                }

                var studyLoad = new StudyLoad
                {
                    StudyLoadID = Guid.NewGuid(),
                    UserID = dto.UserId,
                    ClassID = classId,
                    LoadStatus = 1, // Enrolled
                    CreatedAt = DateTime.UtcNow,
                    CreatedByUserID = createdByUserId
                };

                await _studyLoadRepository.AddAsync(studyLoad);

                var created = await _studyLoadRepository.GetByIdAsync(studyLoad.StudyLoadID);
                if (created != null)
                {
                    resultList.Add(await MapToDtoAsync(created));
                }
            }

            await transaction.CommitAsync();
            return resultList;
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    public async Task<EnrollSingleResponseDto> EnrollSingleAsync(EnrollSingleRequestDto dto, Guid createdByUserId)
    {
        var targetClass = await _context.Classes
            .Include(c => c.Subject)
            .Include(c => c.Term)
            .FirstOrDefaultAsync(c => c.ClassID == dto.ClassId);

        if (targetClass == null)
        {
            throw new KeyNotFoundException($"Class with ID '{dto.ClassId}' was not found.");
        }

        var subjectId = targetClass.SubjectID;
        var termId = targetClass.TermID;
        var warnings = new List<string>();

        await ValidatePriorTermClearanceAsync(dto.UserId, termId);

        // ── 1. Prerequisite Check ───────────────────────────────────────
        var prereqs = await _context.SubjectPrerequisites
            .AsNoTracking()
            .Include(sp => sp.PrerequisiteSubject)
            .Where(sp => sp.SubjectID == subjectId)
            .ToListAsync();

        if (prereqs.Count > 0)
        {
            foreach (var sp in prereqs)
            {
                var prereqSubjectId = sp.PrerequisiteSubjectID;
                var prereqSubjectCode = sp.PrerequisiteSubject?.SubjectCode ?? "Unknown";
                var prereqSubjectTitle = sp.PrerequisiteSubject?.SubjectTitle ?? "Unknown";

                // Check if student has a Grade with Remarks = 1 (Passed) for this prerequisite subject
                bool passed = await _context.Grades
                    .AsNoTracking()
                    .AnyAsync(g => g.StudyLoad != null &&
                                   g.StudyLoad.UserID == dto.UserId &&
                                   g.StudyLoad.Class != null &&
                                   g.StudyLoad.Class.SubjectID == prereqSubjectId &&
                                   g.Remarks == 1);

                if (!passed)
                {
                    warnings.Add($"Prerequisite not met: {prereqSubjectCode} - {prereqSubjectTitle}");
                }
            }
        }

        // ── 2. Schedule Conflict Check ──────────────────────────────────
        var newSchedules = await _context.ClassSchedules
            .AsNoTracking()
            .Where(cs => cs.ClassID == dto.ClassId)
            .ToListAsync();

        if (newSchedules.Count > 0)
        {
            var activeLoads = await _studyLoadRepository.GetActiveByUserAndTermAsync(dto.UserId, termId);

            foreach (var load in activeLoads)
            {
                if (load.ClassID == dto.ClassId)
                {
                    continue;
                }

                var existingSchedules = await _context.ClassSchedules
                    .AsNoTracking()
                    .Where(cs => cs.ClassID == load.ClassID)
                    .ToListAsync();

                var existingSubjectCode = load.Class?.Subject?.SubjectCode ?? "Unknown";

                foreach (var newSched in newSchedules)
                {
                    var newDays = ParseDays(newSched.DaysOfWeek);

                    foreach (var existSched in existingSchedules)
                    {
                        var existDays = ParseDays(existSched.DaysOfWeek);
                        bool daysOverlap = newDays.Intersect(existDays).Any();

                        if (daysOverlap)
                        {
                            bool timeOverlap = newSched.StartTime < existSched.EndTime && newSched.EndTime > existSched.StartTime;
                            if (timeOverlap)
                            {
                                warnings.Add($"Schedule conflict with {existingSubjectCode} ({existSched.DaysOfWeek} {existSched.StartTime:HH:mm}-{existSched.EndTime:HH:mm})");
                            }
                        }
                    }
                }
            }
        }

        // ── Evaluation ──────────────────────────────────────────────────
        if (warnings.Count > 0 && !dto.Force)
        {
            return new EnrollSingleResponseDto
            {
                Success = false,
                StudyLoadId = null,
                Warnings = warnings
            };
        }

        // Check if active study load already exists
        var existingActive = await _studyLoadRepository.GetByUserAndClassAsync(dto.UserId, dto.ClassId);
        if (existingActive != null && existingActive.LoadStatus == 1)
        {
            return new EnrollSingleResponseDto
            {
                Success = true,
                StudyLoadId = existingActive.StudyLoadID,
                Warnings = warnings
            };
        }

        var studyLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = dto.UserId,
            ClassID = dto.ClassId,
            LoadStatus = 1, // Enrolled
            CreatedAt = DateTime.UtcNow,
            CreatedByUserID = createdByUserId
        };

        await _studyLoadRepository.AddAsync(studyLoad);

        return new EnrollSingleResponseDto
        {
            Success = true,
            StudyLoadId = studyLoad.StudyLoadID,
            Warnings = warnings
        };
    }

    public async Task<StudyLoadResponseDto> UpdateStatusAsync(Guid studyLoadId, int newStatus)
    {
        var studyLoad = await _studyLoadRepository.GetByIdAsync(studyLoadId);
        if (studyLoad == null)
        {
            throw new KeyNotFoundException($"StudyLoad with ID '{studyLoadId}' was not found.");
        }

        studyLoad.LoadStatus = newStatus;
        await _studyLoadRepository.UpdateAsync(studyLoad);

        var updated = await _studyLoadRepository.GetByIdAsync(studyLoadId);
        return await MapToDtoAsync(updated!);
    }

    public async Task<List<StudyLoadResponseDto>> GetByStudentAsync(Guid userId, Guid termId)
    {
        var loads = await _studyLoadRepository.GetByUserAndTermAsync(userId, termId);
        var result = new List<StudyLoadResponseDto>();

        foreach (var sl in loads)
        {
            result.Add(await MapToDtoAsync(sl));
        }

        return result;
    }

    public async Task<List<StudyLoadResponseDto>> GetByClassAsync(Guid classId)
    {
        var loads = await _studyLoadRepository.GetByClassIdAsync(classId);
        var result = new List<StudyLoadResponseDto>();

        var userIds = loads.Select(sl => sl.UserID).Distinct().ToList();
        var userDetailsList = await _context.UserDetails
            .AsNoTracking()
            .Where(ud => userIds.Contains(ud.UserID))
            .ToListAsync();
        var userDetailsMap = userDetailsList.ToDictionary(ud => ud.UserID);

        foreach (var sl in loads)
        {
            string? studentName = null;
            if (userDetailsMap.TryGetValue(sl.UserID, out var ud) &&
                (!string.IsNullOrWhiteSpace(ud.Firstname) || !string.IsNullOrWhiteSpace(ud.Lastname)))
            {
                studentName = $"{ud.Firstname} {ud.Lastname}".Trim();
            }
            else if (sl.User != null && !string.IsNullOrWhiteSpace(sl.User.Email))
            {
                studentName = sl.User.Email;
            }

            result.Add(await MapToDtoAsync(sl, studentName));
        }

        return result;
    }

    // ── Helper Methods ─────────────────────────────────────────────────
    private async Task<StudyLoadResponseDto> MapToDtoAsync(StudyLoad sl, string? studentName = null)
    {
        string? teacherName = null;
        if (sl.Class != null && sl.Class.UserID.HasValue)
        {
            teacherName = await ResolveTeacherNameAsync(sl.Class.UserID.Value);
        }

        string termLabel = "N/A";
        if (sl.Class?.Term != null)
        {
            termLabel = $"{sl.Class.Term.SchoolYear} (Sem {sl.Class.Term.Semester})";
        }

        decimal units = 0;
        if (sl.Class?.Subject != null)
        {
            units = sl.Class.Subject.LecUnits + sl.Class.Subject.LabUnits;
        }

        var schedules = sl.Class?.ClassSchedules?
            .Select(s => new ClassScheduleItemDto
            {
                ScheduleId = s.ScheduleID,
                ClassId = s.ClassID,
                DaysOfWeek = s.DaysOfWeek,
                StartTime = s.StartTime,
                EndTime = s.EndTime,
                Room = s.Room
            })
            .ToList() ?? new List<ClassScheduleItemDto>();

        return new StudyLoadResponseDto
        {
            StudyLoadId = sl.StudyLoadID,
            ClassId = sl.ClassID,
            StudentUserId = sl.UserID,
            StudentName = studentName,
            SubjectCode = sl.Class?.Subject?.SubjectCode ?? "N/A",
            SubjectTitle = sl.Class?.Subject?.SubjectTitle ?? "N/A",
            Units = units,
            ClassName = sl.Class?.ClassName ?? "N/A",
            TeacherName = teacherName,
            LoadStatus = FormatLoadStatus(sl.LoadStatus),
            TermLabel = termLabel,
            Schedules = schedules
        };
    }

    private async Task<string?> ResolveTeacherNameAsync(Guid? teacherUserId)
    {
        if (!teacherUserId.HasValue) return null;

        var userDetails = await _context.UserDetails
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.UserID == teacherUserId.Value);

        if (userDetails != null)
        {
            return $"{userDetails.Firstname} {userDetails.Lastname}".Trim();
        }

        var user = await _context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.UserID == teacherUserId.Value);

        return user?.Email;
    }

    private async Task ValidatePriorTermClearanceAsync(Guid userId, Guid enrollingTermId)
    {
        var priorTerm = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.UserID == userId && sl.Class != null && sl.Class.TermID != enrollingTermId)
            .Select(sl => sl.Class!.Term)
            .Where(t => t != null)
            .OrderByDescending(t => t!.SchoolYear)
            .ThenByDescending(t => t!.Semester)
            .FirstOrDefaultAsync();

        if (priorTerm != null)
        {
            bool isCleared = await _clearanceService.IsClearedAsync(userId, priorTerm.TermID);
            if (!isCleared)
            {
                string termLabel = $"{priorTerm.SchoolYear} (Sem {priorTerm.Semester})";
                throw new InvalidOperationException($"Cannot enroll: student has an unresolved clearance hold for {termLabel}.");
            }
        }
    }

    private async Task<string> FormatClassScheduleAsync(Guid classId)
    {
        var schedules = await _context.ClassSchedules
            .AsNoTracking()
            .Where(cs => cs.ClassID == classId)
            .ToListAsync();

        if (schedules.Count == 0)
        {
            return "TBA";
        }

        return string.Join("; ", schedules.Select(s => $"{s.DaysOfWeek} {s.StartTime:HH:mm}-{s.EndTime:HH:mm} ({s.Room})"));
    }

    private static string FormatLoadStatus(int status)
    {
        return status switch
        {
            1 => "Enrolled",
            2 => "Dropped",
            3 => "Withdrawn",
            _ => $"Status {status}"
        };
    }

    private static HashSet<string> ParseDays(string daysOfWeek)
    {
        return daysOfWeek
            .Split(new[] { '/', ',', ' ' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(d => d.ToUpperInvariant())
            .ToHashSet();
    }
}
