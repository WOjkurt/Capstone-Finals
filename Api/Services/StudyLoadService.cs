using Api.Auth;
using Api.Common;
using Api.Constants;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Api.Services;

public class StudyLoadService : IStudyLoadService
{
    private readonly AppDbContext _context;
    private readonly IStudyLoadRepository _studyLoadRepository;
    private readonly IGradeClearanceService _clearanceService;
    private readonly ILogger<StudyLoadService> _logger;

    public StudyLoadService(AppDbContext context, IStudyLoadRepository studyLoadRepository, IGradeClearanceService clearanceService, ILogger<StudyLoadService> logger)
    {
        _context = context;
        _studyLoadRepository = studyLoadRepository;
        _clearanceService = clearanceService;
        _logger = logger;
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
            var prereqs = await _context.SubjectPrerequisites
                .AsNoTracking()
                .Include(sp => sp.PrerequisiteSubject)
                .Where(sp => sp.SubjectID == subject.SubjectID && sp.RequisiteType == RequisiteTypeConstants.Prerequisite)
                .ToListAsync();

            var prereqMessages = new List<string>();
            foreach (var sp in prereqs)
            {
                var pCode = sp.PrerequisiteSubject?.SubjectCode ?? "Unknown";
                var pTitle = sp.PrerequisiteSubject?.SubjectTitle ?? "Unknown";

                var prereqResult = await HasSatisfiedSubjectAsync(userId, sp.PrerequisiteSubjectID);
                switch (prereqResult.Status)
                {
                    case SubjectCompletionStatus.Passed:
                        break;
                    case SubjectCompletionStatus.NeverTaken:
                        prereqMessages.Add($"Prerequisite not met: {pCode} - {pTitle} (never taken)");
                        break;
                    case SubjectCompletionStatus.Failed:
                        string? gradeStr = prereqResult.LastGrade.HasValue
                            ? prereqResult.LastGrade.Value.ToString("0.0#")
                            : null;
                        prereqMessages.Add(gradeStr != null
                            ? $"Prerequisite not met: {pCode} - {pTitle} (failed, last grade {gradeStr})"
                            : $"Prerequisite not met: {pCode} - {pTitle} (failed)");
                        break;
                    case SubjectCompletionStatus.InProgress:
                        prereqMessages.Add($"Prerequisite not met: {pCode} - {pTitle} (grade not yet encoded)");
                        break;
                    case SubjectCompletionStatus.DroppedOrWithdrawn:
                        prereqMessages.Add($"Prerequisite not met: {pCode} - {pTitle} (dropped or withdrawn)");
                        break;
                }
            }

            string prereqStatus = prereqMessages.Count > 0 ? "unmet" : "met";

            // ── Proposed Block Flags ──────────────────────────────────────────
            var subjectSatisfaction = await HasSatisfiedSubjectAsync(userId, subject.SubjectID);
            bool alreadyPassed = subjectSatisfaction.Status == SubjectCompletionStatus.Passed;

            bool alreadyEnrolledThisTerm = await _context.StudyLoads
                .AsNoTracking()
                .AnyAsync(sl => sl.UserID == userId &&
                                (sl.LoadStatus == StudyLoadStatus.Enrolled || sl.LoadStatus == StudyLoadStatus.Pending) &&
                                sl.Class != null &&
                                sl.Class.TermID == termId &&
                                sl.Class.SubjectID == subject.SubjectID);

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
                    Options = null,
                    PrerequisiteStatus = prereqStatus,
                    PrerequisiteMessages = prereqMessages,
                    AlreadyPassed = alreadyPassed,
                    AlreadyEnrolledThisTerm = alreadyEnrolledThisTerm
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
                    Options = null,
                    PrerequisiteStatus = prereqStatus,
                    PrerequisiteMessages = prereqMessages,
                    AlreadyPassed = alreadyPassed,
                    AlreadyEnrolledThisTerm = alreadyEnrolledThisTerm
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
                    Options = options,
                    PrerequisiteStatus = prereqStatus,
                    PrerequisiteMessages = prereqMessages,
                    AlreadyPassed = alreadyPassed,
                    AlreadyEnrolledThisTerm = alreadyEnrolledThisTerm
                });
            }
        }

        return result;
    }

    public async Task<List<EnrollBatchResponseDto>> EnrollBatchAsync(EnrollBatchRequestDto dto, Guid createdByUserId)
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
            var resultList = new List<EnrollBatchResponseDto>();
            var newlyEnrolledCount = 0;
            var enrolledSubjectIdsInBatch = new HashSet<Guid>();

            foreach (var classId in dto.ClassIds)
            {
                var targetClass = await _context.Classes
                    .Include(c => c.Subject)
                    .Include(c => c.Term)
                    .FirstOrDefaultAsync(c => c.ClassID == classId);

                if (targetClass == null)
                {
                    throw new KeyNotFoundException($"Class with ID '{classId}' was not found.");
                }

                var findings = await ValidateEnrollmentRulesAsync(dto.UserId, classId, dto.TermId);

                if (enrolledSubjectIdsInBatch.Contains(targetClass.SubjectID))
                {
                    findings.Add(new EnrollmentValidationFinding
                    {
                        Code = EnrollmentRuleCodes.SameSubjectThisTerm,
                        Message = $"Student already has an active or pending enrollment for this subject in the current term: {targetClass.Subject?.SubjectCode ?? "Unknown"} - {targetClass.Subject?.SubjectTitle ?? "Unknown"} (SAME_SUBJECT_THIS_TERM)",
                        SubjectId = targetClass.SubjectID,
                        SubjectCode = targetClass.Subject?.SubjectCode
                    });
                }

                if (findings.Count > 0)
                {
                    resultList.Add(new EnrollBatchResponseDto
                    {
                        ClassId = classId,
                        Enrolled = false,
                        StudyLoadId = null,
                        Reasons = findings.Select(f => f.Message).ToList()
                    });
                    continue;
                }

                var studyLoad = new StudyLoad
                {
                    StudyLoadID = Guid.NewGuid(),
                    UserID = dto.UserId,
                    ClassID = classId,
                    LoadStatus = StudyLoadStatus.Enrolled,
                    CreatedAt = DateTime.UtcNow,
                    CreatedByUserID = createdByUserId
                };

                await _studyLoadRepository.AddAsync(studyLoad);
                newlyEnrolledCount++;
                enrolledSubjectIdsInBatch.Add(targetClass.SubjectID);

                resultList.Add(new EnrollBatchResponseDto
                {
                    ClassId = classId,
                    Enrolled = true,
                    StudyLoadId = studyLoad.StudyLoadID,
                    Reasons = new List<string>()
                });
            }

            // Ensure exactly one GradeClearance row exists for this student + term (idempotent)
            if (newlyEnrolledCount > 0)
            {
                await _clearanceService.EnsureClearanceAsync(dto.UserId, dto.TermId);
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

        // Check if active study load already exists for this exact class
        var existingActive = await _studyLoadRepository.GetByUserAndClassAsync(dto.UserId, dto.ClassId);
        if (existingActive != null && (existingActive.LoadStatus == StudyLoadStatus.Enrolled || existingActive.LoadStatus == StudyLoadStatus.Pending))
        {
            return new EnrollSingleResponseDto
            {
                Success = true,
                StudyLoadId = existingActive.StudyLoadID,
                Warnings = new List<string>()
            };
        }

        var warnings = new List<string>();

        await ValidatePriorTermClearanceAsync(dto.UserId, termId);

        // ── 1. Shared Enrollment Rules Check ─────────────────────────────
        var findings = await ValidateEnrollmentRulesAsync(dto.UserId, dto.ClassId, termId);
        foreach (var finding in findings)
        {
            warnings.Add(finding.Message);
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

        // ── Force Reason Validation ──────────────────────────────────────
        bool isForced = warnings.Count > 0 && dto.Force;
        string? trimmedReason = dto.ForceReason?.Trim();

        if (isForced)
        {
            if (string.IsNullOrWhiteSpace(trimmedReason))
            {
                return new EnrollSingleResponseDto
                {
                    Success = false,
                    StudyLoadId = null,
                    Warnings = new List<string> { "ForceReason is required when forcing enrollment past validation findings." }
                };
            }

            if (trimmedReason.Length > Api.Constants.ValidationConstants.NotesMax)
            {
                return new EnrollSingleResponseDto
                {
                    Success = false,
                    StudyLoadId = null,
                    Warnings = new List<string> { $"ForceReason must not exceed {Api.Constants.ValidationConstants.NotesMax} characters." }
                };
            }
        }

        var studyLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = dto.UserId,
            ClassID = dto.ClassId,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow,
            CreatedByUserID = createdByUserId,
            IsForced = isForced,
            ForcedByUserID = isForced ? createdByUserId : null,
            ForcedReason = isForced ? trimmedReason : null
        };

        await _studyLoadRepository.AddAsync(studyLoad);

        if (isForced)
        {
            // Log metadata only: student id, class id, caller id, and reason length only. Never log the reason text.
            _logger.LogWarning(
                "Forced enrollment: StudentID={StudentId}, ClassID={ClassId}, CallerID={CallerId}, ReasonLength={ReasonLength}",
                dto.UserId, dto.ClassId, createdByUserId, trimmedReason!.Length);
        }

        // Ensure exactly one GradeClearance row exists for this student + term (idempotent)
        await _clearanceService.EnsureClearanceAsync(dto.UserId, termId);

        return new EnrollSingleResponseDto
        {
            Success = true,
            StudyLoadId = studyLoad.StudyLoadID,
            Warnings = warnings
        };
    }

    private enum SubjectCompletionStatus
    {
        Passed,
        Failed,
        InProgress,
        DroppedOrWithdrawn,
        NeverTaken
    }

    private class SubjectSatisfactionResult
    {
        public SubjectCompletionStatus Status { get; set; }
        public decimal? LastGrade { get; set; }
    }

    public async Task<List<EnrollmentValidationFinding>> ValidateEnrollmentRulesAsync(Guid userId, Guid classId, Guid termId)
    {
        var targetClass = await _context.Classes
            .AsNoTracking()
            .Include(c => c.Subject)
            .FirstOrDefaultAsync(c => c.ClassID == classId);

        if (targetClass == null)
        {
            throw new KeyNotFoundException($"Class with ID '{classId}' was not found.");
        }

        var subjectId = targetClass.SubjectID;
        var subjectCode = targetClass.Subject?.SubjectCode ?? "Unknown";
        var subjectTitle = targetClass.Subject?.SubjectTitle ?? "Unknown";
        var findings = new List<EnrollmentValidationFinding>();

        // ── 1. ALREADY_PASSED Check ──────────────────────────────────────
        var subjectResult = await HasSatisfiedSubjectAsync(userId, subjectId);
        if (subjectResult.Status == SubjectCompletionStatus.Passed)
        {
            findings.Add(new EnrollmentValidationFinding
            {
                Code = EnrollmentRuleCodes.AlreadyPassed,
                Message = $"Student has already passed this subject: {subjectCode} - {subjectTitle} (ALREADY_PASSED)",
                SubjectId = subjectId,
                SubjectCode = subjectCode
            });
        }

        // ── 2. SAME_SUBJECT_THIS_TERM Check ──────────────────────────────
        bool sameSubjectThisTerm = await _context.StudyLoads
            .AsNoTracking()
            .AnyAsync(sl => sl.UserID == userId &&
                            (sl.LoadStatus == StudyLoadStatus.Enrolled || sl.LoadStatus == StudyLoadStatus.Pending) &&
                            sl.Class != null &&
                            sl.Class.TermID == termId &&
                            sl.Class.SubjectID == subjectId);

        if (sameSubjectThisTerm)
        {
            findings.Add(new EnrollmentValidationFinding
            {
                Code = EnrollmentRuleCodes.SameSubjectThisTerm,
                Message = $"Student already has an active or pending enrollment for this subject in the current term: {subjectCode} - {subjectTitle} (SAME_SUBJECT_THIS_TERM)",
                SubjectId = subjectId,
                SubjectCode = subjectCode
            });
        }

        // ── 3. Direct Prerequisite Checks ────────────────────────────────
        var prereqs = await _context.SubjectPrerequisites
            .AsNoTracking()
            .Include(sp => sp.PrerequisiteSubject)
            .Where(sp => sp.SubjectID == subjectId && sp.RequisiteType == RequisiteTypeConstants.Prerequisite)
            .ToListAsync();

        foreach (var sp in prereqs)
        {
            var pCode = sp.PrerequisiteSubject?.SubjectCode ?? "Unknown";
            var pTitle = sp.PrerequisiteSubject?.SubjectTitle ?? "Unknown";

            var prereqResult = await HasSatisfiedSubjectAsync(userId, sp.PrerequisiteSubjectID);
            switch (prereqResult.Status)
            {
                case SubjectCompletionStatus.Passed:
                    break;

                case SubjectCompletionStatus.NeverTaken:
                    findings.Add(new EnrollmentValidationFinding
                    {
                        Code = EnrollmentRuleCodes.PrerequisiteNotTaken,
                        Message = $"Prerequisite not met: {pCode} - {pTitle} (never taken)",
                        SubjectId = sp.PrerequisiteSubjectID,
                        SubjectCode = pCode
                    });
                    break;

                case SubjectCompletionStatus.Failed:
                    string? gradeStr = prereqResult.LastGrade.HasValue
                        ? prereqResult.LastGrade.Value.ToString("0.0#")
                        : null;
                    string failedMsg = gradeStr != null
                        ? $"Prerequisite not met: {pCode} - {pTitle} (failed, last grade {gradeStr})"
                        : $"Prerequisite not met: {pCode} - {pTitle} (failed)";
                    findings.Add(new EnrollmentValidationFinding
                    {
                        Code = EnrollmentRuleCodes.PrerequisiteFailed,
                        Message = failedMsg,
                        SubjectId = sp.PrerequisiteSubjectID,
                        SubjectCode = pCode
                    });
                    break;

                case SubjectCompletionStatus.InProgress:
                    findings.Add(new EnrollmentValidationFinding
                    {
                        Code = EnrollmentRuleCodes.PrerequisiteInProgress,
                        Message = $"Prerequisite not met: {pCode} - {pTitle} (grade not yet encoded)",
                        SubjectId = sp.PrerequisiteSubjectID,
                        SubjectCode = pCode
                    });
                    break;

                case SubjectCompletionStatus.DroppedOrWithdrawn:
                    findings.Add(new EnrollmentValidationFinding
                    {
                        Code = EnrollmentRuleCodes.PrerequisiteDropped,
                        Message = $"Prerequisite not met: {pCode} - {pTitle} (dropped or withdrawn)",
                        SubjectId = sp.PrerequisiteSubjectID,
                        SubjectCode = pCode
                    });
                    break;
            }
        }

        return findings;
    }

    private async Task<SubjectSatisfactionResult> HasSatisfiedSubjectAsync(Guid userId, Guid subjectId)
    {
        var loads = await _context.StudyLoads
            .AsNoTracking()
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Term)
            .Where(sl => sl.UserID == userId && sl.Class != null && sl.Class.SubjectID == subjectId)
            .ToListAsync();

        if (loads.Count == 0)
        {
            return new SubjectSatisfactionResult { Status = SubjectCompletionStatus.NeverTaken };
        }

        var loadIds = loads.Select(sl => sl.StudyLoadID).ToList();
        var grades = await _context.Grades
            .AsNoTracking()
            .Where(g => loadIds.Contains(g.StudyLoadID))
            .ToListAsync();
        var gradeMap = grades.ToDictionary(g => g.StudyLoadID);

        // Only StudyLoads with LoadStatus == Enrolled count as evidence.
        // A Pending load is NOT evidence. Dropped and Withdrawn loads are NOT evidence.
        var nonPendingLoads = loads.Where(sl => sl.LoadStatus != StudyLoadStatus.Pending).ToList();
        if (nonPendingLoads.Count == 0)
        {
            return new SubjectSatisfactionResult { Status = SubjectCompletionStatus.NeverTaken };
        }

        // 1. Check if student passed on an Enrolled load anywhere ("a Passed grade anywhere clears earlier Failed ones")
        bool hasPassed = nonPendingLoads.Any(sl =>
            sl.LoadStatus == StudyLoadStatus.Enrolled &&
            gradeMap.TryGetValue(sl.StudyLoadID, out var g) &&
            g.Remarks == 1);

        if (hasPassed)
        {
            return new SubjectSatisfactionResult { Status = SubjectCompletionStatus.Passed };
        }

        // 2. Check if the subject is currently in progress: student has an Enrolled load with no final grade
        bool hasInProgress = nonPendingLoads.Any(sl =>
            sl.LoadStatus == StudyLoadStatus.Enrolled &&
            (!gradeMap.TryGetValue(sl.StudyLoadID, out var g) || !g.Remarks.HasValue || (g.Remarks != 1 && g.Remarks != 2)));

        if (hasInProgress)
        {
            return new SubjectSatisfactionResult { Status = SubjectCompletionStatus.InProgress };
        }

        // 3. Check for Failed grade on an Enrolled load
        var failedLoads = nonPendingLoads
            .Where(sl => sl.LoadStatus == StudyLoadStatus.Enrolled &&
                         gradeMap.TryGetValue(sl.StudyLoadID, out var g) &&
                         g.Remarks == 2)
            .OrderByDescending(sl => sl.Class?.Term?.SchoolYear)
            .ThenByDescending(sl => sl.Class?.Term?.Semester)
            .ThenByDescending(sl => sl.CreatedAt)
            .ToList();

        if (failedLoads.Count > 0)
        {
            var latestGrade = gradeMap[failedLoads[0].StudyLoadID];
            return new SubjectSatisfactionResult
            {
                Status = SubjectCompletionStatus.Failed,
                LastGrade = latestGrade.FinalGrade
            };
        }

        // 4. Check if student only has Dropped or Withdrawn loads
        bool hasDroppedOrWithdrawn = nonPendingLoads.Any(sl =>
            sl.LoadStatus == StudyLoadStatus.Dropped || sl.LoadStatus == StudyLoadStatus.Withdrawn);

        if (hasDroppedOrWithdrawn)
        {
            return new SubjectSatisfactionResult { Status = SubjectCompletionStatus.DroppedOrWithdrawn };
        }

        return new SubjectSatisfactionResult { Status = SubjectCompletionStatus.NeverTaken };
    }

    public async Task<StudyLoadResponseDto> UpdateStatusAsync(Guid studyLoadId, int newStatus)
    {
        if (!StudyLoadStatus.IsValid(newStatus))
        {
            throw new ArgumentException($"Invalid LoadStatus '{newStatus}'.");
        }

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

    public async Task<List<StudyLoadResponseDto>> GetByStudentAsync(Guid userId, Guid termId, bool isStudentCaller = false, int? callerRole = null)
    {
        var loads = await _studyLoadRepository.GetByUserAndTermAsync(userId, termId);
        var result = new List<StudyLoadResponseDto>();

        var ud = await _context.UserDetails.AsNoTracking().FirstOrDefaultAsync(u => u.UserID == userId);

        int effectiveRole;
        if (callerRole.HasValue)
        {
            effectiveRole = callerRole.Value;
        }
        else if (isStudentCaller)
        {
            effectiveRole = RoleUtils.Student;
        }
        else
        {
            effectiveRole = RoleUtils.Registrar;
        }

        bool? hasLrn = null;
        string? lrn = null;

        if (effectiveRole == RoleUtils.Teacher)
        {
            hasLrn = null;
            lrn = null;
        }
        else if (effectiveRole == RoleUtils.Registrar || effectiveRole == RoleUtils.Admin || effectiveRole == RoleUtils.CollegeHead)
        {
            hasLrn = !string.IsNullOrWhiteSpace(ud?.LRN);
            lrn = ud?.LRN;
        }
        else if (effectiveRole == RoleUtils.ProgramHead || effectiveRole == RoleUtils.Student)
        {
            hasLrn = !string.IsNullOrWhiteSpace(ud?.LRN);
            lrn = null;
        }

        bool maskForceAudit = (effectiveRole == RoleUtils.Student) || isStudentCaller;

        foreach (var sl in loads)
        {
            result.Add(await MapToDtoAsync(sl, isStudentCaller: maskForceAudit, hasLrn: hasLrn, lrn: lrn));
        }

        return result;
    }

    public async Task<List<StudyLoadResponseDto>> GetByClassAsync(Guid classId, bool excludePending = false, int? callerRole = null)
    {
        var loads = await _studyLoadRepository.GetByClassIdAsync(classId);
        if (excludePending)
        {
            loads = loads.Where(sl => sl.LoadStatus != StudyLoadStatus.Pending).ToList();
        }
        var result = new List<StudyLoadResponseDto>();

        var userIds = loads.Select(sl => sl.UserID).Distinct().ToList();
        var userDetailsList = await _context.UserDetails
            .AsNoTracking()
            .Where(ud => userIds.Contains(ud.UserID))
            .ToListAsync();
        var userDetailsMap = userDetailsList.ToDictionary(ud => ud.UserID);

        int effectiveRole;
        if (callerRole.HasValue)
        {
            effectiveRole = callerRole.Value;
        }
        else if (excludePending)
        {
            effectiveRole = RoleUtils.Teacher;
        }
        else
        {
            effectiveRole = RoleUtils.Registrar;
        }

        foreach (var sl in loads)
        {
            string? studentName = null;
            bool? studentHasLrn = null;
            string? studentLrn = null;

            if (userDetailsMap.TryGetValue(sl.UserID, out var ud))
            {
                if (!string.IsNullOrWhiteSpace(ud.Firstname) || !string.IsNullOrWhiteSpace(ud.Lastname))
                {
                    studentName = $"{ud.Firstname} {ud.Lastname}".Trim();
                }

                if (effectiveRole == RoleUtils.Teacher)
                {
                    studentHasLrn = null;
                    studentLrn = null;
                }
                else if (effectiveRole == RoleUtils.Registrar || effectiveRole == RoleUtils.Admin || effectiveRole == RoleUtils.CollegeHead)
                {
                    studentHasLrn = !string.IsNullOrWhiteSpace(ud.LRN);
                    studentLrn = ud.LRN;
                }
                else if (effectiveRole == RoleUtils.ProgramHead || effectiveRole == RoleUtils.Student)
                {
                    studentHasLrn = !string.IsNullOrWhiteSpace(ud.LRN);
                    studentLrn = null;
                }
            }
            else if (sl.User != null && !string.IsNullOrWhiteSpace(sl.User.Email))
            {
                studentName = sl.User.Email;
            }

            result.Add(await MapToDtoAsync(sl, studentName, hasLrn: studentHasLrn, lrn: studentLrn));
        }

        return result;
    }

    // ── Helper Methods ─────────────────────────────────────────────────
    private async Task<StudyLoadResponseDto> MapToDtoAsync(StudyLoad sl, string? studentName = null, bool isStudentCaller = false, bool? hasLrn = null, string? lrn = null)
    {
        string? teacherName = null;
        if (sl.Class != null && sl.Class.UserID.HasValue)
        {
            teacherName = await ResolveTeacherNameAsync(sl.Class.UserID.Value);
        }

        string termLabel = "N/A";
        if (sl.Class?.Term != null)
        {
            termLabel = TermLabel.Format(sl.Class.Term.SchoolYear, sl.Class.Term.Semester);
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
            Schedules = schedules,
            IsForced = sl.IsForced,
            ForcedByUserID = isStudentCaller ? null : sl.ForcedByUserID,
            ForcedReason = isStudentCaller ? null : sl.ForcedReason,
            HasLrn = hasLrn,
            LRN = lrn
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
            .Where(sl => sl.UserID == userId && sl.LoadStatus == StudyLoadStatus.Enrolled && sl.Class != null && sl.Class.TermID != enrollingTermId)
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
                string termLabel = TermLabel.Format(priorTerm.SchoolYear, priorTerm.Semester);
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
        return StudyLoadStatus.GetDisplayText(status);
    }

    private static HashSet<string> ParseDays(string daysOfWeek)
    {
        return daysOfWeek
            .Split(new[] { '/', ',', ' ' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(d => d.ToUpperInvariant())
            .ToHashSet();
    }
}
