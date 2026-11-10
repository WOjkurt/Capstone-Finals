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

        var programSubjects = await _context.Subjects
            .AsNoTracking()
            .ForStudent(userDetails)
            .ToListAsync();

        var candidates = new List<(Subject Subject, string Category, decimal? LastGrade, string? LastGradeTerm)>();

        foreach (var s in programSubjects)
        {
            var satisfaction = await HasSatisfiedSubjectAsync(userId, s.SubjectID);

            bool isEarlierYear = s.YearLevel < userDetails.YearLevel.Value;
            bool isEarlierSemesterOfSameYear = s.YearLevel == userDetails.YearLevel.Value &&
                                               s.DefaultSemester < term.Semester;

            // 1. retake: latest attempt is Failed and never passed later (reuse HasSatisfiedSubjectAsync, status Failed). Any year level.
            if (satisfaction.Status == SubjectCompletionStatus.Failed)
            {
                candidates.Add((s, "retake", satisfaction.LastGrade, satisfaction.LastGradeTerm));
            }
            // 2. back_subject: earlier year level OR earlier semester of student's own year level,
            //    AND never taken (NeverTaken) or only dropped/withdrawn, and not in-progress or passed. Rejected loads are ignored.
            else if (isEarlierYear || isEarlierSemesterOfSameYear)
            {
                if (satisfaction.Status == SubjectCompletionStatus.NeverTaken || satisfaction.Status == SubjectCompletionStatus.DroppedOrWithdrawn)
                {
                    candidates.Add((s, "back_subject", null, null));
                }
            }
            // 3. regular: Subject.YearLevel == student year level AND DefaultSemester == term.Semester
            else if (s.YearLevel == userDetails.YearLevel.Value && s.DefaultSemester == term.Semester)
            {
                candidates.Add((s, "regular", null, null));
            }
        }

        var candidateSubjectIds = candidates.Select(c => c.Subject.SubjectID).ToHashSet();
        var allCandidateIdsList = candidates.Select(c => c.Subject.SubjectID).ToList();

        var allCoreqLinks = await _context.SubjectPrerequisites
            .AsNoTracking()
            .Include(sp => sp.Subject)
            .Include(sp => sp.PrerequisiteSubject)
            .Where(sp => sp.RequisiteType == RequisiteTypeConstants.Corequisite &&
                         (allCandidateIdsList.Contains(sp.SubjectID) || allCandidateIdsList.Contains(sp.PrerequisiteSubjectID)))
            .ToListAsync();

        var result = new List<ProposedBlockItemDto>();

        foreach (var (subject, category, lastGrade, lastGradeTerm) in candidates)
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

            string standingStatus = "not_required";
            if (subject.StandingYear.HasValue)
            {
                standingStatus = userDetails.YearLevel.Value >= subject.StandingYear.Value ? "met" : "unmet";
            }

            var coreqDtos = new List<ProposedBlockCorequisiteDto>();
            var seenCoreqIds = new HashSet<Guid>();
            foreach (var link in allCoreqLinks)
            {
                Subject? other = null;
                if (link.SubjectID == subject.SubjectID && link.PrerequisiteSubject != null)
                {
                    other = link.PrerequisiteSubject;
                }
                else if (link.PrerequisiteSubjectID == subject.SubjectID && link.Subject != null)
                {
                    other = link.Subject;
                }

                if (other != null && seenCoreqIds.Add(other.SubjectID))
                {
                    coreqDtos.Add(new ProposedBlockCorequisiteDto
                    {
                        SubjectId = other.SubjectID,
                        SubjectCode = other.SubjectCode,
                        IncludedInProposal = candidateSubjectIds.Contains(other.SubjectID)
                    });
                }
            }

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

            decimal units = subject.LecUnits + subject.LabUnits;

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
                    AlreadyEnrolledThisTerm = alreadyEnrolledThisTerm,
                    Category = category,
                    SubjectYearLevel = subject.YearLevel,
                    Units = units,
                    LastGrade = lastGrade,
                    LastGradeTerm = lastGradeTerm,
                    StandingStatus = standingStatus,
                    Corequisites = coreqDtos
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
                    AlreadyEnrolledThisTerm = alreadyEnrolledThisTerm,
                    Category = category,
                    SubjectYearLevel = subject.YearLevel,
                    Units = units,
                    LastGrade = lastGrade,
                    LastGradeTerm = lastGradeTerm,
                    StandingStatus = standingStatus,
                    Corequisites = coreqDtos
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
                    AlreadyEnrolledThisTerm = alreadyEnrolledThisTerm,
                    Category = category,
                    SubjectYearLevel = subject.YearLevel,
                    Units = units,
                    LastGrade = lastGrade,
                    LastGradeTerm = lastGradeTerm,
                    StandingStatus = standingStatus,
                    Corequisites = coreqDtos
                });
            }
        }

        int CategoryRank(string cat) => cat switch
        {
            "regular" => 1,
            "retake" => 2,
            "back_subject" => 3,
            _ => 4
        };

        return result
            .OrderBy(r => CategoryRank(r.Category))
            .ThenBy(r => r.SubjectYearLevel)
            .ThenBy(r => r.SubjectCode, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    public async Task<List<EnrollBatchResponseDto>> EnrollBatchAsync(EnrollBatchRequestDto dto, Guid createdByUserId, int? callerRole = null)
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

        int targetStatus = (callerRole == RoleUtils.CollegeHead || dto.AsPending)
            ? StudyLoadStatus.Pending
            : StudyLoadStatus.Enrolled;

        await ValidatePriorTermClearanceAsync(dto.UserId, dto.TermId);

        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            var resultList = new List<EnrollBatchResponseDto>();
            var newlyEnrolledCount = 0;
            var enrolledSubjectIdsInBatch = new HashSet<Guid>();
            var accepted = new List<(Guid ClassId, EnrollBatchResponseDto Result, decimal Units)>();

            // Pass 1: check every class without saving, so the unit limit can be checked on the whole batch.
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

                enrolledSubjectIdsInBatch.Add(targetClass.SubjectID);
                var result = new EnrollBatchResponseDto { ClassId = classId, Enrolled = true, Reasons = new List<string>() };
                resultList.Add(result);
                accepted.Add((classId, result, (targetClass.Subject?.LecUnits ?? 0m) + (targetClass.Subject?.LabUnits ?? 0m)));
            }

            // Going over the CHED unit limit needs a written reason, which is recorded as the overload approval.
            // (Skipped for accounts without student details, which have no program or year to measure against.)
            if (accepted.Count > 0 && await _context.UserDetails.AnyAsync(u => u.UserID == dto.UserId))
            {
                var limit = await GetUnitLimitAsync(dto.UserId, dto.TermId);
                decimal projected = limit.CurrentUnits + accepted.Sum(a => a.Units);
                if (projected > limit.MaxUnits)
                {
                    string? reason = dto.OverloadReason?.Trim();
                    if (string.IsNullOrEmpty(reason))
                    {
                        throw new InvalidOperationException(
                            $"This load would be {projected:0.#} units, over the limit of {limit.MaxUnits:0.#}. Enter a reason to approve the overload.");
                    }

                    var approval = await _context.OverloadApprovals
                        .FirstOrDefaultAsync(o => o.UserID == dto.UserId && o.TermID == dto.TermId);
                    if (approval == null)
                    {
                        approval = new OverloadApproval
                        {
                            OverloadApprovalID = Guid.NewGuid(),
                            UserID = dto.UserId,
                            TermID = dto.TermId,
                            Reason = reason
                        };
                        _context.OverloadApprovals.Add(approval);
                    }
                    approval.Units = projected;
                    approval.MaxUnits = limit.MaxUnits;
                    approval.Reason = reason;
                    approval.ApprovedByUserID = createdByUserId;
                    approval.ApprovedAt = DateTime.UtcNow;
                    await _context.SaveChangesAsync();
                }
            }

            // Pass 2: save the accepted classes.
            foreach (var (classId, result, _) in accepted)
            {
                var studyLoad = new StudyLoad
                {
                    StudyLoadID = Guid.NewGuid(),
                    UserID = dto.UserId,
                    ClassID = classId,
                    LoadStatus = targetStatus,
                    CreatedAt = DateTime.UtcNow,
                    CreatedByUserID = createdByUserId
                };

                await _studyLoadRepository.AddAsync(studyLoad);
                newlyEnrolledCount++;
                result.StudyLoadId = studyLoad.StudyLoadID;
            }

            // Ensure exactly one GradeClearance row exists for this student + term (idempotent)
            // Only create clearance if loads are enrolled directly
            if (newlyEnrolledCount > 0 && targetStatus == StudyLoadStatus.Enrolled)
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

    public async Task<EnrollSingleResponseDto> EnrollSingleAsync(EnrollSingleRequestDto dto, Guid createdByUserId, int? callerRole = null)
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

        // ── Force Reason & Authorization Validation ─────────────────────
        bool isForced = warnings.Count > 0 && dto.Force;
        string? trimmedReason = dto.ForceReason?.Trim();

        if (isForced)
        {
            if (findings.Any(f => !f.CanForce))
            {
                return new EnrollSingleResponseDto
                {
                    Success = false,
                    StudyLoadId = null,
                    Warnings = warnings
                };
            }

            int? effectiveRole = callerRole;
            if (!effectiveRole.HasValue)
            {
                var callerUser = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.UserID == createdByUserId);
                effectiveRole = callerUser?.Role;
            }

            int resolvedRole = effectiveRole ?? Api.Auth.RoleUtils.Registrar;
            if (resolvedRole != Api.Auth.RoleUtils.Registrar &&
                resolvedRole != Api.Auth.RoleUtils.CollegeHead &&
                resolvedRole != Api.Auth.RoleUtils.Admin)
            {
                return new EnrollSingleResponseDto
                {
                    Success = false,
                    StudyLoadId = null,
                    Warnings = new List<string>(warnings) { "Only College Head and Registrar can force enrollment." }
                };
            }

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

        int targetStatus = (callerRole == RoleUtils.CollegeHead || dto.AsPending)
            ? StudyLoadStatus.Pending
            : StudyLoadStatus.Enrolled;

        var studyLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = dto.UserId,
            ClassID = dto.ClassId,
            LoadStatus = targetStatus,
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
        // Only if creating Enrolled loads
        if (targetStatus == StudyLoadStatus.Enrolled)
        {
            await _clearanceService.EnsureClearanceAsync(dto.UserId, termId);
        }

        return new EnrollSingleResponseDto
        {
            Success = true,
            StudyLoadId = studyLoad.StudyLoadID,
            Warnings = warnings
        };
    }

    /// <summary>Share of a year level's units a student must pass to move up.</summary>
    public const decimal PromotionPassRatio = 0.75m;

    public async Task<YearLevelSuggestionDto> GetYearLevelSuggestionAsync(Guid userId)
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
            throw new InvalidOperationException("Cannot suggest a year level: the student's program and year level must both be set.");
        }

        int current = userDetails.YearLevel.Value;
        var programSubjects = await _context.Subjects
            .AsNoTracking()
            .ForStudent(userDetails)
            .ToListAsync();

        var currentSubjects = programSubjects.Where(s => s.YearLevel == current).ToList();
        var statuses = new Dictionary<Guid, SubjectCompletionStatus>();
        foreach (var subject in currentSubjects)
        {
            statuses[subject.SubjectID] = (await HasSatisfiedSubjectAsync(userId, subject.SubjectID)).Status;
        }

        return BuildYearLevelSuggestion(current, programSubjects, s => statuses[s.SubjectID]);
    }

    /// <summary>
    /// Suggestions for every active student of a program (optionally one year level), for end-of-year promotion.
    /// Loads all attempts at once instead of per subject; the status rule is the same <see cref="ClassifyAttempts"/>.
    /// </summary>
    public async Task<List<StudentYearLevelSuggestionDto>> GetYearLevelSuggestionsAsync(int programId, int? yearLevel)
    {
        var students = await _context.UserDetails
            .AsNoTracking()
            .Where(ud => ud.ProgramID == programId && ud.YearLevel != null &&
                         ud.User != null && ud.User.Role == RoleUtils.Student && ud.User.IsActive &&
                         (yearLevel == null || ud.YearLevel == yearLevel))
            .ToListAsync();
        if (students.Count == 0)
        {
            return new List<StudentYearLevelSuggestionDto>();
        }

        var programSubjects = await _context.Subjects.AsNoTracking().Where(s => s.ProgramID == programId).ToListAsync();
        var subjectIds = programSubjects.Select(s => s.SubjectID).ToList();
        var userIds = students.Select(s => s.UserID).ToList();

        var attempts = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => userIds.Contains(sl.UserID) && sl.Class != null && subjectIds.Contains(sl.Class.SubjectID))
            .Select(sl => new { sl.StudyLoadID, sl.UserID, SubjectID = sl.Class!.SubjectID, sl.LoadStatus })
            .ToListAsync();
        var loadIds = attempts.Select(a => a.StudyLoadID).ToList();
        var remarks = await _context.Grades
            .AsNoTracking()
            .Where(g => loadIds.Contains(g.StudyLoadID))
            .ToDictionaryAsync(g => g.StudyLoadID, g => g.Remarks);
        // Only credits with the subject's full units count as passed.
        var credited = (await _context.CreditedSubjects
                .AsNoTracking()
                .Where(c => userIds.Contains(c.UserID) && subjectIds.Contains(c.SubjectID) &&
                            c.CreditedUnits >= c.Subject!.LecUnits + c.Subject.LabUnits)
                .Select(c => new { c.UserID, c.SubjectID })
                .ToListAsync())
            .Select(c => (c.UserID, c.SubjectID))
            .ToHashSet();
        var attemptsBy = attempts.ToLookup(a => (a.UserID, a.SubjectID));

        // Each student is measured against their own curriculum (old records without one: the whole program).
        var byCurriculum = programSubjects.ToLookup(s => s.CurriculumID);
        var result = new List<StudentYearLevelSuggestionDto>();
        foreach (var student in students.OrderBy(s => s.YearLevel).ThenBy(s => s.Lastname).ThenBy(s => s.Firstname))
        {
            var mySubjects = student.CurriculumID is { } cid ? byCurriculum[cid].ToList() : programSubjects;
            var suggestion = BuildYearLevelSuggestion(student.YearLevel!.Value, mySubjects, subject =>
                ClassifyAttempts(
                    credited.Contains((student.UserID, subject.SubjectID)),
                    attemptsBy[(student.UserID, subject.SubjectID)]
                        .Select(a => (a.LoadStatus, remarks.TryGetValue(a.StudyLoadID, out var r) ? r : null))));

            result.Add(new StudentYearLevelSuggestionDto
            {
                UserId = student.UserID,
                FullName = $"{student.Firstname} {student.Lastname}".Trim(),
                Lrn = student.LRN,
                Suggestion = suggestion
            });
        }
        return result;
    }

    /// <summary>Sets several students' year levels at once. All-or-nothing: one invalid entry saves nothing.</summary>
    public async Task<int> ApplyYearLevelsAsync(List<YearLevelChangeDto> changes)
    {
        if (changes.Count == 0)
        {
            return 0;
        }
        if (changes.Select(c => c.UserId).Distinct().Count() != changes.Count)
        {
            throw new InvalidOperationException("Each student may appear only once.");
        }
        var bad = changes.FirstOrDefault(c => c.YearLevel < 1 || c.YearLevel > 5);
        if (bad != null)
        {
            throw new InvalidOperationException("Year level must be between 1 and 5.");
        }

        var ids = changes.Select(c => c.UserId).ToList();
        var details = await _context.UserDetails
            .Include(ud => ud.User)
            .Where(ud => ids.Contains(ud.UserID))
            .ToListAsync();
        var students = details.Where(ud => ud.User?.Role == RoleUtils.Student).ToDictionary(ud => ud.UserID);
        if (students.Count != changes.Count)
        {
            throw new KeyNotFoundException("One or more students were not found.");
        }

        foreach (var change in changes)
        {
            var ud = students[change.UserId];
            _logger.LogInformation("Bulk YearLevel update: UserID={UserId}, Old={Old}, New={New}", ud.UserID, ud.YearLevel, change.YearLevel);
            ud.YearLevel = change.YearLevel;
        }
        await _context.SaveChangesAsync();
        return changes.Count;
    }

    private static YearLevelSuggestionDto BuildYearLevelSuggestion(
        int current, List<Subject> programSubjects, Func<Subject, SubjectCompletionStatus> statusOf)
    {
        var result = new YearLevelSuggestionDto { CurrentYearLevel = current, SuggestedYearLevel = current };
        int finalYear = programSubjects.Count > 0 ? programSubjects.Max(s => s.YearLevel) : current;
        result.IsFinalYear = current >= finalYear;

        foreach (var s in programSubjects.Where(s => s.YearLevel == current).OrderBy(s => s.SubjectCode))
        {
            decimal units = s.LecUnits + s.LabUnits;
            result.TotalSubjects++;
            result.TotalUnits += units;
            if (!s.IsMinor) result.TotalMajorUnits += units;

            switch (statusOf(s))
            {
                case SubjectCompletionStatus.Passed:
                    result.PassedSubjects++;
                    result.PassedUnits += units;
                    if (!s.IsMinor) result.PassedMajorUnits += units;
                    break;
                case SubjectCompletionStatus.Failed:
                    result.FailedSubjectCodes.Add(s.SubjectCode);
                    break;
                case SubjectCompletionStatus.InProgress:
                    result.UngradedSubjects++;
                    break;
                default:
                    result.NotTakenSubjectCodes.Add(s.SubjectCode);
                    break;
            }
        }

        if (result.TotalUnits == 0)
        {
            result.Reason = $"No subjects with units were found for Year {current} of this program.";
            return result;
        }

        int percent = (int)Math.Floor(result.PassedUnits / result.TotalUnits * 100);
        string summary = $"Passed {result.PassedUnits:0.#} of {result.TotalUnits:0.#} units ({percent}%) of Year {current} subjects; " +
                         $"{PromotionPassRatio * 100:0}% is needed to move up.";

        // Passing mostly minor subjects (GE, theology, PE) must not be enough on its own.
        bool enoughUnits = result.PassedUnits >= result.TotalUnits * PromotionPassRatio;
        bool enoughMajorUnits = result.TotalMajorUnits == 0 ||
                                result.PassedMajorUnits >= result.TotalMajorUnits * PromotionPassRatio;
        if (enoughUnits && !enoughMajorUnits)
        {
            int majorPercent = (int)Math.Floor(result.PassedMajorUnits / result.TotalMajorUnits * 100);
            summary = $"Passed {result.PassedUnits:0.#} of {result.TotalUnits:0.#} units ({percent}%), " +
                      $"but only {result.PassedMajorUnits:0.#} of {result.TotalMajorUnits:0.#} major units ({majorPercent}%); " +
                      $"{PromotionPassRatio * 100:0}% of major units is needed to move up.";
        }

        if (result.IsFinalYear)
        {
            result.Reason = $"Year {current} is the final year of this program. {summary}";
        }
        else if (enoughUnits && enoughMajorUnits)
        {
            result.SuggestedYearLevel = current + 1;
            result.Reason = summary;
        }
        else
        {
            result.Reason = summary;
        }

        if (result.UngradedSubjects > 0)
        {
            result.Reason += $" {result.UngradedSubjects} subject(s) still have no final grade.";
        }

        return result;
    }

    // CHED norms (CMO / MORPHE): no overload for non-graduating students; up to 6 extra units when graduating;
    // summer capped at 9 units (12 when graduating). Used for warnings only.
    public const decimal DefaultRegularMaxUnits = 21m;
    public const decimal GraduatingOverloadUnits = 6m;
    /// <summary>Defaults until the Registrar saves their own in Setup → Unit Limits.</summary>
    public const decimal SummerMaxUnits = 9m;
    public const decimal GraduatingSummerMaxUnits = 12m;

    public async Task<UnitLimitDto> GetUnitLimitAsync(Guid userId, Guid termId)
    {
        var userDetails = await _context.UserDetails
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.UserID == userId)
            ?? throw new KeyNotFoundException($"UserDetails not found for user '{userId}'.");

        var term = await _context.AcademicTerms
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.TermID == termId)
            ?? throw new KeyNotFoundException($"AcademicTerm with ID '{termId}' was not found.");

        var programSubjects = userDetails.ProgramID.HasValue
            ? await _context.Subjects.AsNoTracking().ForStudent(userDetails).ToListAsync()
            : new List<Subject>();

        int? yearLevel = userDetails.YearLevel;
        bool isGraduating = yearLevel.HasValue && programSubjects.Count > 0 && yearLevel.Value >= programSubjects.Max(s => s.YearLevel);
        bool isSummer = term.Semester == 3;

        decimal curriculumUnits = yearLevel.HasValue
            ? programSubjects.Where(s => s.YearLevel == yearLevel.Value && s.DefaultSemester == term.Semester)
                             .Sum(s => s.LecUnits + s.LabUnits)
            : 0m;

        decimal currentUnits = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.UserID == userId && sl.Class != null && sl.Class.TermID == termId &&
                         (sl.LoadStatus == StudyLoadStatus.Enrolled || sl.LoadStatus == StudyLoadStatus.Pending))
            .Select(sl => sl.Class!.Subject!.LecUnits + sl.Class!.Subject!.LabUnits)
            .SumAsync();

        decimal max;
        string rule;
        if (isSummer)
        {
            // The Registrar can change these in Setup; until then the defaults apply.
            var settings = await _context.SchoolSettings.AsNoTracking().FirstOrDefaultAsync();
            max = isGraduating
                ? settings?.GraduatingSummerMaxUnits ?? GraduatingSummerMaxUnits
                : settings?.SummerMaxUnits ?? SummerMaxUnits;
            rule = isGraduating ? $"Summer limit for graduating students: {max:0.#} units." : $"Summer limit: {max:0.#} units.";
        }
        else
        {
            decimal regular = curriculumUnits > 0 ? curriculumUnits : DefaultRegularMaxUnits;
            string basis = curriculumUnits > 0 ? $"curriculum load {regular:0.#} units" : $"{regular:0.#} units (no curriculum load found)";
            max = isGraduating ? regular + GraduatingOverloadUnits : regular;
            rule = isGraduating
                ? $"Regular limit is the {basis}, plus up to {GraduatingOverloadUnits:0} units overload for graduating students."
                : $"Regular limit is the {basis}. Overload is allowed only for graduating students.";
        }

        var approval = await _context.OverloadApprovals
            .AsNoTracking()
            .FirstOrDefaultAsync(o => o.UserID == userId && o.TermID == termId);
        string? approvedBy = null;
        if (approval != null)
        {
            var approver = await _context.UserDetails.AsNoTracking().FirstOrDefaultAsync(u => u.UserID == approval.ApprovedByUserID);
            approvedBy = approver != null ? $"{approver.Firstname} {approver.Lastname}".Trim() : null;
        }

        return new UnitLimitDto
        {
            MaxUnits = max,
            CurrentUnits = currentUnits,
            CurriculumUnits = curriculumUnits,
            IsGraduating = isGraduating,
            IsSummer = isSummer,
            Rule = rule,
            OverloadReason = approval?.Reason,
            OverloadApprovedBy = approval != null ? (approvedBy ?? "Unknown staff") : null,
            OverloadApprovedAt = approval?.ApprovedAt
        };
    }

    internal enum SubjectCompletionStatus
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
        public string? LastGradeTerm { get; set; }
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

        // ── 4. Standing Requirement Check ────────────────────────────────
        if (targetClass.Subject?.StandingYear.HasValue == true)
        {
            var userDetails = await _context.UserDetails
                .AsNoTracking()
                .FirstOrDefaultAsync(ud => ud.UserID == userId);

            if (userDetails == null || !userDetails.YearLevel.HasValue)
            {
                findings.Add(new EnrollmentValidationFinding
                {
                    Code = EnrollmentRuleCodes.YearLevelNotSet,
                    Message = $"Student year level is not set: {subjectCode} - {subjectTitle} requires Year {targetClass.Subject.StandingYear.Value} standing (YEAR_LEVEL_NOT_SET)",
                    SubjectId = subjectId,
                    SubjectCode = subjectCode,
                    CanForce = false
                });
            }
            else if (userDetails.YearLevel.Value < targetClass.Subject.StandingYear.Value)
            {
                findings.Add(new EnrollmentValidationFinding
                {
                    Code = EnrollmentRuleCodes.StandingYearRequired,
                    Message = $"Standing requirement not met: {subjectCode} - {subjectTitle} requires Year {targetClass.Subject.StandingYear.Value} standing (student is Year {userDetails.YearLevel.Value}) (STANDING_YEAR_REQUIRED)",
                    SubjectId = subjectId,
                    SubjectCode = subjectCode,
                    CanForce = true
                });
            }
        }

        return findings;
    }

    /// <summary>
    /// The pass/fail rule for one subject, given whether it is credited and the student's study loads of it
    /// (load status and final-grade remarks). Pending and Rejected loads are not evidence; a pass anywhere wins.
    /// </summary>
    internal static SubjectCompletionStatus ClassifyAttempts(bool credited, IEnumerable<(int LoadStatus, int? Remarks)> attempts)
    {
        if (credited) return SubjectCompletionStatus.Passed;

        var counted = attempts
            .Where(a => a.LoadStatus != StudyLoadStatus.Pending && a.LoadStatus != StudyLoadStatus.Rejected)
            .ToList();
        if (counted.Any(a => a.LoadStatus == StudyLoadStatus.Enrolled && a.Remarks == 1)) return SubjectCompletionStatus.Passed;
        if (counted.Any(a => a.LoadStatus == StudyLoadStatus.Enrolled && a.Remarks is not (1 or 2))) return SubjectCompletionStatus.InProgress;
        if (counted.Any(a => a.LoadStatus == StudyLoadStatus.Enrolled && a.Remarks == 2)) return SubjectCompletionStatus.Failed;
        if (counted.Any(a => a.LoadStatus == StudyLoadStatus.Dropped || a.LoadStatus == StudyLoadStatus.Withdrawn))
            return SubjectCompletionStatus.DroppedOrWithdrawn;
        return SubjectCompletionStatus.NeverTaken;
    }

    private async Task<SubjectSatisfactionResult> HasSatisfiedSubjectAsync(Guid userId, Guid subjectId)
    {
        // A subject credited from another school with its full units counts as passed; a partial credit does not.
        if (await _context.CreditedSubjects.AnyAsync(c => c.UserID == userId && c.SubjectID == subjectId &&
                                                          c.CreditedUnits >= c.Subject!.LecUnits + c.Subject.LabUnits))
        {
            return new SubjectSatisfactionResult { Status = SubjectCompletionStatus.Passed };
        }

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
        // A Rejected proposal is NOT evidence anywhere (must not count as dropped, failed, or taken).
        var nonPendingLoads = loads.Where(sl => sl.LoadStatus != StudyLoadStatus.Pending && sl.LoadStatus != StudyLoadStatus.Rejected).ToList();
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
            var latestLoad = failedLoads[0];
            var latestGrade = gradeMap[latestLoad.StudyLoadID];
            string? termLabel = latestLoad.Class?.Term != null
                ? TermLabel.Format(latestLoad.Class.Term.SchoolYear, latestLoad.Class.Term.Semester)
                : null;

            return new SubjectSatisfactionResult
            {
                Status = SubjectCompletionStatus.Failed,
                LastGrade = latestGrade.FinalGrade,
                LastGradeTerm = termLabel
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

    public async Task<StudyLoadResponseDto> UpdateStatusAsync(Guid studyLoadId, int newStatus, int? callerRole = null)
    {
        if (!StudyLoadStatus.IsValid(newStatus))
        {
            throw new ArgumentException($"Invalid LoadStatus '{newStatus}'.");
        }

        if (newStatus == StudyLoadStatus.Pending)
        {
            throw new InvalidOperationException("Pending status cannot be set via this endpoint.");
        }

        var studyLoad = await _studyLoadRepository.GetByIdAsync(studyLoadId);
        if (studyLoad == null)
        {
            throw new KeyNotFoundException($"StudyLoad with ID '{studyLoadId}' was not found.");
        }

        var oldStatus = studyLoad.LoadStatus;

        if (newStatus == StudyLoadStatus.Rejected && oldStatus != StudyLoadStatus.Pending)
        {
            throw new InvalidOperationException($"Only Pending study loads can be marked as Rejected. Current status is '{StudyLoadStatus.GetDisplayText(oldStatus)}'.");
        }

        studyLoad.LoadStatus = newStatus;
        await _studyLoadRepository.UpdateAsync(studyLoad);

        if (oldStatus == StudyLoadStatus.Pending && newStatus == StudyLoadStatus.Enrolled)
        {
            var termId = studyLoad.Class?.TermID;
            if (termId.HasValue)
            {
                await _clearanceService.EnsureClearanceAsync(studyLoad.UserID, termId.Value);
            }
        }

        var updated = await _studyLoadRepository.GetByIdAsync(studyLoadId);
        int effectiveRole = callerRole ?? RoleUtils.Registrar;
        return await MapToDtoAsync(updated!, callerRole: effectiveRole);
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

        foreach (var sl in loads)
        {
            result.Add(await MapToDtoAsync(sl, callerRole: effectiveRole, hasLrn: hasLrn, lrn: lrn));
        }

        return result;
    }

    public async Task<List<StudyLoadResponseDto>> GetByClassAsync(Guid classId, bool excludePending = false, int? callerRole = null)
    {
        var loads = await _studyLoadRepository.GetByClassIdAsync(classId);
        // Rosters hide Rejected loads by default across all views (Teacher, Registrar, Program Head, etc.)
        loads = loads.Where(sl => sl.LoadStatus != StudyLoadStatus.Rejected).ToList();
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

            result.Add(await MapToDtoAsync(sl, studentName, callerRole: effectiveRole, hasLrn: studentHasLrn, lrn: studentLrn));
        }

        return result;
    }

    // ── Helper Methods ─────────────────────────────────────────────────
    private async Task<StudyLoadResponseDto> MapToDtoAsync(StudyLoad sl, string? studentName = null, int? callerRole = null, bool? hasLrn = null, string? lrn = null)
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

        var dto = new StudyLoadResponseDto
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
            ForcedByUserID = sl.ForcedByUserID,
            ForcedReason = sl.ForcedReason,
            HasLrn = hasLrn,
            LRN = lrn
        };

        dto.ApplyForceAuditMask(callerRole);
        return dto;
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
        var enrolling = await _context.AcademicTerms.AsNoTracking().FirstOrDefaultAsync(t => t.TermID == enrollingTermId);
        var otherTerms = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.UserID == userId && sl.LoadStatus == StudyLoadStatus.Enrolled && sl.Class != null && sl.Class.TermID != enrollingTermId)
            .Select(sl => sl.Class!.Term)
            .Where(t => t != null)
            .Distinct()
            .ToListAsync();

        // Only an earlier term can hold up enrollment; a late add to the current term must not trip on a later one.
        var priorTerm = otherTerms
            .Where(t => enrolling == null || IsEarlier(t!, enrolling))
            .OrderByDescending(t => t!.SchoolYear, StringComparer.Ordinal)
            .ThenByDescending(t => t!.Semester)
            .FirstOrDefault();

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

    private static bool IsEarlier(AcademicTerm a, AcademicTerm b)
    {
        int year = string.CompareOrdinal(a.SchoolYear, b.SchoolYear);
        return year != 0 ? year < 0 : a.Semester < b.Semester;
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

    public async Task<FinalizeStudyLoadsResponseDto> FinalizeBatchAsync(FinalizeStudyLoadsRequestDto dto, Guid callerUserId, int? callerRole = null)
    {
        int effectiveRole = callerRole ?? RoleUtils.Registrar;
        if (effectiveRole != RoleUtils.Registrar && effectiveRole != RoleUtils.Admin)
        {
            throw new UnauthorizedAccessException("Access denied. Only Registrar and Admin can finalize study loads.");
        }

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

        List<StudyLoad> selectedLoads;
        if (dto.StudyLoadIds != null && dto.StudyLoadIds.Count > 0)
        {
            selectedLoads = await _context.StudyLoads
                .Include(sl => sl.Class)
                    .ThenInclude(c => c!.Subject)
                .Include(sl => sl.Class)
                    .ThenInclude(c => c!.Term)
                .Include(sl => sl.Class)
                    .ThenInclude(c => c!.ClassSchedules)
                .Where(sl => dto.StudyLoadIds.Contains(sl.StudyLoadID) && sl.UserID == dto.UserId)
                .ToListAsync();

            if (selectedLoads.Count != dto.StudyLoadIds.Count)
            {
                throw new KeyNotFoundException("One or more specified study loads were not found for this student.");
            }

            foreach (var sl in selectedLoads)
            {
                if (sl.Class?.TermID != dto.TermId)
                {
                    throw new ArgumentException($"Study load '{sl.StudyLoadID}' belongs to a different term.");
                }
                if (sl.LoadStatus != StudyLoadStatus.Pending)
                {
                    throw new InvalidOperationException($"Only Pending study loads can be finalized. StudyLoad '{sl.StudyLoadID}' has status '{StudyLoadStatus.GetDisplayText(sl.LoadStatus)}'.");
                }
            }
        }
        else
        {
            selectedLoads = await _context.StudyLoads
                .Include(sl => sl.Class)
                    .ThenInclude(c => c!.Subject)
                .Include(sl => sl.Class)
                    .ThenInclude(c => c!.Term)
                .Include(sl => sl.Class)
                    .ThenInclude(c => c!.ClassSchedules)
                .Where(sl => sl.UserID == dto.UserId && sl.Class != null && sl.Class.TermID == dto.TermId && sl.LoadStatus == StudyLoadStatus.Pending)
                .ToListAsync();
        }

        if (selectedLoads.Count == 0)
        {
            return new FinalizeStudyLoadsResponseDto
            {
                Success = true,
                FinalizedLoads = new List<StudyLoadResponseDto>(),
                Message = "No pending study loads to finalize."
            };
        }

        // Validate prior term clearance
        await ValidatePriorTermClearanceAsync(dto.UserId, dto.TermId);

        var allFindings = new List<EnrollmentValidationFinding>();
        var selectedIds = selectedLoads.Select(sl => sl.StudyLoadID).ToHashSet();

        foreach (var sl in selectedLoads)
        {
            if (sl.Class == null)
            {
                allFindings.Add(new EnrollmentValidationFinding
                {
                    Code = "CLASS_NOT_FOUND",
                    Message = "The class associated with this study load no longer exists.",
                    CanForce = false
                });
                continue;
            }

            // 1. ALREADY_PASSED check
            var subjectResult = await HasSatisfiedSubjectAsync(dto.UserId, sl.Class.SubjectID);
            if (subjectResult.Status == SubjectCompletionStatus.Passed)
            {
                allFindings.Add(new EnrollmentValidationFinding
                {
                    Code = EnrollmentRuleCodes.AlreadyPassed,
                    Message = $"Student has already passed this subject: {sl.Class.Subject?.SubjectCode ?? "Unknown"} - {sl.Class.Subject?.SubjectTitle ?? "Unknown"} (ALREADY_PASSED)",
                    SubjectId = sl.Class.SubjectID,
                    SubjectCode = sl.Class.Subject?.SubjectCode,
                    CanForce = false
                });
            }

            // 2. SAME_SUBJECT_THIS_TERM check (excluding loads currently being finalized)
            bool otherSameSubject = await _context.StudyLoads
                .AsNoTracking()
                .AnyAsync(other => other.UserID == dto.UserId &&
                                   !selectedIds.Contains(other.StudyLoadID) &&
                                   other.Class != null &&
                                   other.Class.TermID == dto.TermId &&
                                   other.Class.SubjectID == sl.Class.SubjectID &&
                                   (other.LoadStatus == StudyLoadStatus.Enrolled || other.LoadStatus == StudyLoadStatus.Pending));

            if (otherSameSubject)
            {
                allFindings.Add(new EnrollmentValidationFinding
                {
                    Code = EnrollmentRuleCodes.SameSubjectThisTerm,
                    Message = $"Student already has an active or pending enrollment for this subject in the current term: {sl.Class.Subject?.SubjectCode ?? "Unknown"} - {sl.Class.Subject?.SubjectTitle ?? "Unknown"} (SAME_SUBJECT_THIS_TERM)",
                    SubjectId = sl.Class.SubjectID,
                    SubjectCode = sl.Class.Subject?.SubjectCode,
                    CanForce = false
                });
            }

            // 3. Re-run rules for non-forced loads
            if (!sl.IsForced)
            {
                var loadFindings = await ValidateEnrollmentRulesAsync(dto.UserId, sl.ClassID, dto.TermId);
                foreach (var f in loadFindings)
                {
                    // Exclude ALREADY_PASSED and SAME_SUBJECT_THIS_TERM because evaluated without self-conflict above
                    if (f.Code == EnrollmentRuleCodes.AlreadyPassed || f.Code == EnrollmentRuleCodes.SameSubjectThisTerm)
                    {
                        continue;
                    }
                    allFindings.Add(f);
                }
            }
        }

        if (allFindings.Count > 0)
        {
            return new FinalizeStudyLoadsResponseDto
            {
                Success = false,
                Findings = allFindings,
                Message = "Finalization blocked by enrollment rules."
            };
        }

        // All-or-nothing transaction
        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            foreach (var sl in selectedLoads)
            {
                sl.LoadStatus = StudyLoadStatus.Enrolled;
                _context.StudyLoads.Update(sl);
            }
            await _context.SaveChangesAsync();

            // Call EnsureClearanceAsync once for the term
            await _clearanceService.EnsureClearanceAsync(dto.UserId, dto.TermId);

            await transaction.CommitAsync();

            _logger.LogInformation(
                "Study loads finalized: FinalizedBy={FinalizedBy}, StudentID={StudentId}, TermID={TermId}, Count={Count}",
                callerUserId, dto.UserId, dto.TermId, selectedLoads.Count);

            var finalizedDtos = new List<StudyLoadResponseDto>();
            foreach (var sl in selectedLoads)
            {
                finalizedDtos.Add(await MapToDtoAsync(sl, callerRole: effectiveRole));
            }

            return new FinalizeStudyLoadsResponseDto
            {
                Success = true,
                FinalizedLoads = finalizedDtos,
                Message = $"Successfully finalized {selectedLoads.Count} study load(s)."
            };
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    public async Task<List<PendingStudyLoadSummaryDto>> GetPendingSummaryAsync(Guid? termId = null)
    {
        Guid resolvedTermId;
        if (termId.HasValue && termId.Value != Guid.Empty)
        {
            resolvedTermId = termId.Value;
        }
        else
        {
            var activeTerm = await _context.AcademicTerms.AsNoTracking().FirstOrDefaultAsync(t => t.IsActive);
            if (activeTerm == null)
            {
                return new List<PendingStudyLoadSummaryDto>();
            }
            resolvedTermId = activeTerm.TermID;
        }

        var pendingLoads = await _context.StudyLoads
            .AsNoTracking()
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Subject)
            .Where(sl => sl.LoadStatus == StudyLoadStatus.Pending &&
                         sl.Class != null &&
                         sl.Class.TermID == resolvedTermId)
            .ToListAsync();

        if (pendingLoads.Count == 0)
        {
            return new List<PendingStudyLoadSummaryDto>();
        }

        var userIds = pendingLoads.Select(sl => sl.UserID).Distinct().ToList();
        var userDetailsList = await _context.UserDetails
            .AsNoTracking()
            .Include(ud => ud.Program)
            .Where(ud => userIds.Contains(ud.UserID))
            .ToListAsync();
        var userDetailsMap = userDetailsList.ToDictionary(ud => ud.UserID);

        var grouped = pendingLoads.GroupBy(sl => sl.UserID);
        var result = new List<PendingStudyLoadSummaryDto>();

        foreach (var g in grouped)
        {
            userDetailsMap.TryGetValue(g.Key, out var ud);
            string fullName = ud != null ? $"{ud.Firstname} {ud.Lastname}".Trim() : "Unknown Student";
            decimal totalUnits = g.Sum(sl => (sl.Class?.Subject?.LecUnits ?? 0m) + (sl.Class?.Subject?.LabUnits ?? 0m));

            var limit = await GetUnitLimitAsync(g.Key, resolvedTermId);

            result.Add(new PendingStudyLoadSummaryDto
            {
                TermUnits = limit.CurrentUnits,
                MaxUnits = limit.MaxUnits,
                IsOverloaded = limit.IsOverloaded,
                OverloadReason = limit.OverloadReason,
                OverloadApprovedBy = limit.OverloadApprovedBy,
                UserId = g.Key,
                FullName = fullName,
                Lrn = ud?.LRN,
                ProgramCode = ud?.Program?.ProgramCode,
                ProgramName = ud?.Program?.FullName,
                YearLevel = ud?.YearLevel,
                PendingCount = g.Count(),
                PendingUnits = totalUnits
            });
        }

        return result.OrderBy(r => r.FullName).ToList();
    }
}

