using Api.Auth;
using Api.Common;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.DTOs.Grading;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public class GradeService : IGradeService
{
    private readonly AppDbContext _context;
    private readonly IGradeRepository _gradeRepository;
    private readonly IGradeClearanceService _clearanceService;
    private readonly IProgramScopingService _scopingService;

    public GradeService(
        AppDbContext context,
        IGradeRepository gradeRepository,
        IGradeClearanceService clearanceService,
        IProgramScopingService scopingService)
    {
        _context = context;
        _gradeRepository = gradeRepository;
        _clearanceService = clearanceService;
        _scopingService = scopingService;
    }

    public async Task<GradeResponseDto> SubmitGradeAsync(SubmitGradeDto dto, Guid authenticatedUserId)
    {
        var studyLoad = await _context.StudyLoads
            .AsNoTracking()
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Subject)
            .Include(sl => sl.User)
            .FirstOrDefaultAsync(sl => sl.StudyLoadID == dto.StudyLoadId);

        if (studyLoad == null)
        {
            throw new KeyNotFoundException($"StudyLoad with ID '{dto.StudyLoadId}' was not found.");
        }

        if (studyLoad.Class == null || studyLoad.Class.UserID != authenticatedUserId)
        {
            throw new UnauthorizedAccessException("Only the assigned teacher of this class can submit grades.");
        }

        return await ProcessGradeItemAsync(dto.StudyLoadId, dto.MidtermGrade, dto.FinalGrade, studyLoad, authenticatedUserId);
    }

    public async Task<SubmitGradeBatchResponseDto> SubmitGradeBatchAsync(SubmitGradeBatchDto dto, Guid authenticatedUserId)
    {
        if (dto.ClassId == Guid.Empty)
        {
            throw new ArgumentException("ClassId must be provided.");
        }

        var targetClass = await _context.Classes
            .Include(c => c.Subject)
            .FirstOrDefaultAsync(c => c.ClassID == dto.ClassId);

        if (targetClass == null)
        {
            throw new KeyNotFoundException($"Class with ID '{dto.ClassId}' was not found.");
        }

        if (targetClass.UserID != authenticatedUserId)
        {
            throw new UnauthorizedAccessException("Only the assigned teacher of this class can submit grades.");
        }

        var response = new SubmitGradeBatchResponseDto();

        if (dto.Grades == null || dto.Grades.Count == 0)
        {
            return response;
        }

        var studyLoadIds = dto.Grades.Select(g => g.StudyLoadId).Distinct().ToList();

        var studyLoads = await _context.StudyLoads
            .AsNoTracking()
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Subject)
            .Include(sl => sl.User)
            .Where(sl => studyLoadIds.Contains(sl.StudyLoadID))
            .ToListAsync();

        var studyLoadMap = studyLoads.ToDictionary(sl => sl.StudyLoadID);

        // Validate every studyLoadId in the list belongs to classId (via its Class navigation)
        // Reject the whole request with 400 if any doesn't
        foreach (var item in dto.Grades)
        {
            if (!studyLoadMap.TryGetValue(item.StudyLoadId, out var sl) || sl.Class == null || sl.Class.ClassID != dto.ClassId)
            {
                throw new ArgumentException($"StudyLoad with ID '{item.StudyLoadId}' does not belong to Class '{dto.ClassId}'.");
            }
        }

        foreach (var item in dto.Grades)
        {
            var sl = studyLoadMap[item.StudyLoadId];
            try
            {
                var gradeDto = await ProcessGradeItemAsync(item.StudyLoadId, item.MidtermGrade, item.FinalGrade, sl, authenticatedUserId);
                response.Succeeded.Add(gradeDto);
            }
            catch (InvalidOperationException ex)
            {
                response.Failed.Add(new GradeBatchFailedItemDto
                {
                    StudyLoadId = item.StudyLoadId,
                    Reason = ex.Message
                });
            }
            catch (Exception ex)
            {
                response.Failed.Add(new GradeBatchFailedItemDto
                {
                    StudyLoadId = item.StudyLoadId,
                    Reason = ex.Message
                });
            }
        }

        return response;
    }

    private async Task<GradeResponseDto> ProcessGradeItemAsync(
        Guid studyLoadId,
        decimal? midtermGrade,
        decimal? finalGrade,
        StudyLoad studyLoad,
        Guid authenticatedUserId)
    {
        if (studyLoad.LoadStatus != StudyLoadStatus.Enrolled)
        {
            var statusText = StudyLoadStatus.GetDisplayText(studyLoad.LoadStatus);
            throw new InvalidOperationException($"Cannot submit grade: study load is not actively enrolled (current status: {statusText}).");
        }

        if (!midtermGrade.HasValue && !finalGrade.HasValue)
        {
            throw new InvalidOperationException("At least one grade field (MidtermGrade or FinalGrade) must be provided for submission.");
        }

        var existingGrade = await _gradeRepository.GetByStudyLoadIdAsync(studyLoadId);

        if (existingGrade == null)
        {
            var newGrade = new Grade
            {
                GradeID = Guid.NewGuid(),
                StudyLoadID = studyLoadId,
                MidtermGrade = midtermGrade,
                FinalGrade = finalGrade,
                Remarks = finalGrade.HasValue ? (finalGrade.Value > 3.0m ? 2 : 1) : null,
                SubmittedByUserID = authenticatedUserId,
                DateSubmitted = DateTime.UtcNow
            };

            await _gradeRepository.AddAsync(newGrade);

            var created = await _gradeRepository.GetByIdAsync(newGrade.GradeID);
            var createdGrade = created ?? newGrade;
            if (createdGrade.StudyLoad == null)
            {
                createdGrade.StudyLoad = studyLoad;
            }
            return await MapToDtoAsync(createdGrade);
        }

        // Grade row already exists — check per-field immutability
        bool midtermConflict = midtermGrade.HasValue && existingGrade.MidtermGrade.HasValue;
        bool finalConflict = finalGrade.HasValue && existingGrade.FinalGrade.HasValue;

        if (midtermConflict && finalConflict)
        {
            throw new InvalidOperationException("Both MidtermGrade and FinalGrade have already been submitted. Use a GradeCorrection request to change them.");
        }
        if (midtermConflict)
        {
            throw new InvalidOperationException("MidtermGrade has already been submitted. Use a GradeCorrection request to change it.");
        }
        if (finalConflict)
        {
            throw new InvalidOperationException("FinalGrade has already been submitted. Use a GradeCorrection request to change it.");
        }

        if (midtermGrade.HasValue)
        {
            existingGrade.MidtermGrade = midtermGrade.Value;
        }

        if (finalGrade.HasValue)
        {
            existingGrade.FinalGrade = finalGrade.Value;
        }

        existingGrade.Remarks = existingGrade.FinalGrade.HasValue ? (existingGrade.FinalGrade.Value > 3.0m ? 2 : 1) : null;
        existingGrade.SubmittedByUserID = authenticatedUserId;
        existingGrade.DateSubmitted = DateTime.UtcNow;

        await _gradeRepository.UpdateAsync(existingGrade);

        var updated = await _gradeRepository.GetByIdAsync(existingGrade.GradeID);
        var updatedGrade = updated ?? existingGrade;
        if (updatedGrade.StudyLoad == null)
        {
            updatedGrade.StudyLoad = studyLoad;
        }
        return await MapToDtoAsync(updatedGrade);
    }

    public async Task<GradeResponseDto?> GetByStudyLoadIdAsync(Guid studyLoadId, Guid authenticatedUserId, int authenticatedUserRole)
    {
        // Load the study load with all navigation properties needed for authorization.
        var studyLoad = await _context.StudyLoads
            .AsNoTracking()
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Subject)
            .Include(sl => sl.User)
            .FirstOrDefaultAsync(sl => sl.StudyLoadID == studyLoadId);

        if (studyLoad == null)
        {
            // Return null — caller maps this to 404. Don't reveal existence to unauthorized callers;
            // the 403 below happens only when the record IS found but the caller lacks permission.
            return null;
        }

        // ── Determine caller's relationship to this record ──────────────────────────────────────
        bool isStudent = authenticatedUserRole == RoleUtils.Student;
        bool isStudentOwner = studyLoad.UserID == authenticatedUserId;
        bool isAssignedTeacher = studyLoad.Class?.UserID.HasValue == true &&
                                 studyLoad.Class.UserID!.Value == authenticatedUserId;
        bool isRegistrarOrAdmin = authenticatedUserRole == RoleUtils.Registrar ||
                                  authenticatedUserRole == RoleUtils.Admin ||
                                  authenticatedUserRole == RoleUtils.CollegeHead;
        bool isProgramHead = authenticatedUserRole == RoleUtils.ProgramHead;

        // ── Case (c) — Staff (Registrar / Admin): pass through ──────────────────────────────────
        if (isRegistrarOrAdmin)
        {
            var grade = await _gradeRepository.GetByStudyLoadIdAsync(studyLoadId);
            if (grade == null) return null;
            var fullGrade = await _gradeRepository.GetByIdAsync(grade.GradeID);
            return await MapToDtoAsync(fullGrade ?? grade);
        }

        // ── Case (c) — Program Head: must belong to the class's program ─────────────────────────
        if (isProgramHead)
        {
            if (!isAssignedTeacher)
            {
                // Scope-check: the class's subject program must match the PH's program
                await _scopingService.EnsureProgramHeadAccessAsync(
                    authenticatedUserId,
                    studyLoad.Class?.Subject?.ProgramID,
                    "class");
            }

            var grade = await _gradeRepository.GetByStudyLoadIdAsync(studyLoadId);
            if (grade == null) return null;
            var fullGrade = await _gradeRepository.GetByIdAsync(grade.GradeID);
            return await MapToDtoAsync(fullGrade ?? grade);
        }

        // ── Case (b) — Teacher: must be assigned to this class ──────────────────────────────────
        if (!isStudent)
        {
            // Non-student, non-staff, non-PH: must be the assigned teacher
            if (!isAssignedTeacher)
            {
                throw new UnauthorizedAccessException(
                    "Access denied. You are not the assigned teacher for this class.");
            }

            var grade = await _gradeRepository.GetByStudyLoadIdAsync(studyLoadId);
            if (grade == null) return null;
            var fullGrade = await _gradeRepository.GetByIdAsync(grade.GradeID);
            return await MapToDtoAsync(fullGrade ?? grade);
        }

        // ── Case (a) — Student: must own the study load AND have clearance ──────────────────────
        if (!isStudentOwner)
        {
            throw new UnauthorizedAccessException(
                "Access denied. You can only view your own grades.");
        }

        // Apply the same clearance-masking logic used in GetByStudentIdAsync.
        // If the student's term has not been cleared, return 403 instead of the grade.
        if (studyLoad.Class != null)
        {
            bool cleared = await _clearanceService.IsClearedAsync(authenticatedUserId, studyLoad.Class.TermID);
            if (!cleared)
            {
                throw new UnauthorizedAccessException(
                    "Your grades for this term are withheld pending clearance. Please contact the Registrar.");
            }
        }

        var studentGrade = await _gradeRepository.GetByStudyLoadIdAsync(studyLoadId);
        if (studentGrade == null) return null;
        var fullStudentGrade = await _gradeRepository.GetByIdAsync(studentGrade.GradeID);
        return await MapToDtoAsync(fullStudentGrade ?? studentGrade);
    }


    public async Task<List<GradeResponseDto>> GetByClassIdAsync(Guid classId, Guid authenticatedUserId, int authenticatedUserRole)
    {
        var targetClass = await _context.Classes
            .Include(c => c.Subject)
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.ClassID == classId);

        if (targetClass == null)
        {
            throw new KeyNotFoundException($"Class with ID '{classId}' was not found.");
        }

        bool isStaff = authenticatedUserRole == RoleUtils.Registrar ||
                       authenticatedUserRole == RoleUtils.Admin ||
                       authenticatedUserRole == RoleUtils.ProgramHead ||
                       authenticatedUserRole == RoleUtils.CollegeHead;
        bool isAssignedTeacher = targetClass.UserID.HasValue && targetClass.UserID.Value == authenticatedUserId;

        if (!isStaff && !isAssignedTeacher)
        {
            throw new UnauthorizedAccessException("Access denied. Only the assigned teacher, Registrar, Admin, or Program Head can access class grades.");
        }

        if (authenticatedUserRole == RoleUtils.ProgramHead && !isAssignedTeacher)
        {
            await _scopingService.EnsureProgramHeadAccessAsync(authenticatedUserId, targetClass.Subject?.ProgramID, "class");
        }

        var studyLoads = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.ClassID == classId)
            .Select(sl => sl.StudyLoadID)
            .ToListAsync();

        var grades = await _context.Grades
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.User)
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.Class)
                    .ThenInclude(c => c!.Subject)
            .Include(g => g.SubmittedByUser)
            .Where(g => studyLoads.Contains(g.StudyLoadID))
            .ToListAsync();

        var result = new List<GradeResponseDto>();
        foreach (var g in grades)
        {
            result.Add(await MapToDtoAsync(g));
        }

        return result;
    }

    public async Task<List<GradeResponseDto>> GetByStudentIdAsync(Guid userId, Guid? termId, Guid authenticatedUserId, int authenticatedUserRole)
    {
        bool isSelf = authenticatedUserId == userId;
        bool isStaff = authenticatedUserRole == RoleUtils.Registrar ||
                       authenticatedUserRole == RoleUtils.Admin ||
                       authenticatedUserRole == RoleUtils.ProgramHead ||
                       authenticatedUserRole == RoleUtils.CollegeHead;

        if (!isSelf && !isStaff)
        {
            throw new UnauthorizedAccessException("Access denied. You can only view your own grades unless you are a Registrar, Admin, or Program Head.");
        }

        if (authenticatedUserRole == RoleUtils.ProgramHead && !isSelf)
        {
            var studentDetails = await _context.UserDetails.FirstOrDefaultAsync(ud => ud.UserID == userId);
            await _scopingService.EnsureProgramHeadAccessAsync(authenticatedUserId, studentDetails?.ProgramID, "student");
        }

        var query = _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.UserID == userId);

        if (termId.HasValue)
        {
            query = query.Where(sl => sl.Class != null && sl.Class.TermID == termId.Value);
        }

        var studyLoadIds = await query.Select(sl => sl.StudyLoadID).ToListAsync();

        var grades = await _context.Grades
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.User)
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.Class)
                    .ThenInclude(c => c!.Subject)
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.Class)
                    .ThenInclude(c => c!.Term)
            .Include(g => g.SubmittedByUser)
            .Where(g => studyLoadIds.Contains(g.StudyLoadID))
            .ToListAsync();

        if (isSelf)
        {
            var distinctTermIds = grades
                .Where(g => g.StudyLoad?.Class != null)
                .Select(g => g.StudyLoad!.Class!.TermID)
                .Distinct()
                .ToList();

            var clearedTerms = new HashSet<Guid>();
            foreach (var tId in distinctTermIds)
            {
                if (await _clearanceService.IsClearedAsync(userId, tId))
                {
                    clearedTerms.Add(tId);
                }
            }

            grades = grades
                .Where(g => g.StudyLoad?.Class != null && clearedTerms.Contains(g.StudyLoad.Class.TermID))
                .ToList();
        }

        var result = new List<GradeResponseDto>();
        foreach (var g in grades)
        {
            result.Add(await MapToDtoAsync(g));
        }

        return result;
    }

    // ── Helper Methods ─────────────────────────────────────────────────
    private async Task<GradeResponseDto> MapToDtoAsync(Grade g)
    {
        string? teacherName = await ResolveUserNameAsync(g.SubmittedByUserID);
        if (string.IsNullOrWhiteSpace(teacherName) && g.StudyLoad?.Class?.UserID.HasValue == true)
        {
            teacherName = await ResolveUserNameAsync(g.StudyLoad.Class.UserID.Value);
        }

        Guid? studentUserId = g.StudyLoad?.UserID;
        string? studentName = studentUserId.HasValue ? await ResolveUserNameAsync(studentUserId.Value) : null;
        var subject = g.StudyLoad?.Class?.Subject;
        var term = g.StudyLoad?.Class?.Term;

        return new GradeResponseDto
        {
            GradeId = g.GradeID,
            StudyLoadId = g.StudyLoadID,
            MidtermGrade = g.MidtermGrade,
            FinalGrade = g.FinalGrade,
            Remarks = g.Remarks,
            RemarksLabel = FormatRemarks(g.Remarks),
            SubmittedByUserID = g.SubmittedByUserID,
            TeacherName = teacherName,
            DateSubmitted = g.DateSubmitted,
            StudentUserId = studentUserId,
            StudentName = studentName,
            SubjectCode = g.StudyLoad?.Class?.Subject?.SubjectCode,
            SubjectTitle = g.StudyLoad?.Class?.Subject?.SubjectTitle,
            ClassName = g.StudyLoad?.Class?.ClassName,
            Units = subject != null ? subject.LecUnits + subject.LabUnits : null,
            TermId = term?.TermID,
            SchoolYear = term?.SchoolYear,
            Semester = term?.Semester,
            TermLabel = term != null ? TermLabel.Format(term.SchoolYear, term.Semester) : null,
            LoadStatus = g.StudyLoad?.LoadStatus
        };
    }

    private async Task<string?> ResolveUserNameAsync(Guid userId)
    {
        var ud = await _context.UserDetails
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.UserID == userId);

        if (ud != null && (!string.IsNullOrWhiteSpace(ud.Firstname) || !string.IsNullOrWhiteSpace(ud.Lastname)))
        {
            return $"{ud.Firstname} {ud.Lastname}".Trim();
        }

        return null;
    }

    private static string? FormatRemarks(int? remarks)
    {
        return remarks switch
        {
            1 => "Passed",
            2 => "Failed",
            _ => null
        };
    }
}
