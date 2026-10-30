using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.Grading;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Stage 2 tests: verifies every behavior introduced with the Pending (4) status.
/// Covers enrolled-count filtering, grade submission guards, duplicate/conflict
/// detection, prior-term clearance logic, the PATCH status DTO validation,
/// and StudyLoadStatus display text for all four values.
/// </summary>
public class StudyLoadServiceStage2Tests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly StudyLoadRepository _studyLoadRepo;
    private readonly GradeClearanceRepository _clearanceRepo;
    private readonly GradeClearanceService _clearanceService;
    private readonly StudyLoadService _studyLoadService;
    private readonly ClassService _classService;
    private readonly GradeRepository _gradeRepo;
    private readonly GradeService _gradeService;

    private readonly Guid _registrarId = Guid.NewGuid();
    private readonly Guid _teacherId = Guid.NewGuid();

    public StudyLoadServiceStage2Tests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _studyLoadRepo = new StudyLoadRepository(_context);
        _clearanceRepo = new GradeClearanceRepository(_context);
        _clearanceService = new GradeClearanceService(_context, _clearanceRepo);
        _studyLoadService = new StudyLoadService(_context, _studyLoadRepo, _clearanceService, NullLogger<StudyLoadService>.Instance);

        var classRepo = new ClassRepository(_context);
        var scheduleRepo = new ClassScheduleRepository(_context);
        _classService = new ClassService(_context, classRepo, scheduleRepo);

        _gradeRepo = new GradeRepository(_context);
        var scopingMock = new Mock<IProgramScopingService>();
        _gradeService = new GradeService(_context, _gradeRepo, _clearanceService, scopingMock.Object);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    // ── Seed Helpers ───────────────────────────────────────────────────────────

    private async Task<(Guid subjectId, Guid classId, Guid termId)> SeedClassAsync(
        string subjectCode = "IT101",
        string className = "BSIT-1A",
        string schoolYear = "2025-2026",
        int semester = 1)
    {
        var termId = Guid.NewGuid();
        var subjectId = Guid.NewGuid();
        var classId = Guid.NewGuid();

        _context.AcademicTerms.Add(new AcademicTerm
        {
            TermID = termId,
            SchoolYear = schoolYear,
            Semester = semester,
            IsActive = true
        });
        _context.Subjects.Add(new Subject
        {
            SubjectID = subjectId,
            SubjectCode = subjectCode,
            SubjectTitle = "Test Subject",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = semester,
            LecUnits = 3.0m,
            LabUnits = 0.0m
        });
        _context.Classes.Add(new Class
        {
            ClassID = classId,
            ClassName = className,
            SubjectID = subjectId,
            TermID = termId,
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();
        return (subjectId, classId, termId);
    }

    private async Task<StudyLoad> SeedStudyLoadAsync(
        Guid userId,
        Guid classId,
        int loadStatus,
        DateTime? createdAt = null)
    {
        var sl = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = userId,
            ClassID = classId,
            LoadStatus = loadStatus,
            CreatedAt = createdAt ?? DateTime.UtcNow
        };
        _context.StudyLoads.Add(sl);
        await _context.SaveChangesAsync();
        return sl;
    }

    private async Task SeedTeacherAsync()
    {
        _context.Users.Add(new User
        {
            UserID = _teacherId,
            FirebaseUID = "fb-teacher-" + Guid.NewGuid(),
            Email = "teacher@dbtc.edu.ph",
            Role = 4,
            IsActive = true
        });
        await _context.SaveChangesAsync();
    }

    private async Task<Guid> SeedStudentUserAsync(string emailSuffix = "")
    {
        var id = Guid.NewGuid();
        _context.Users.Add(new User
        {
            UserID = id,
            FirebaseUID = "fb-student-" + Guid.NewGuid(),
            Email = $"student{emailSuffix}@dbtc.edu.ph",
            Role = 5,
            IsActive = true
        });
        await _context.SaveChangesAsync();
        return id;
    }

    private async Task AssignTeacherToClassAsync(Guid classId)
    {
        var cls = await _context.Classes.FindAsync(classId);
        cls!.UserID = _teacherId;
        await _context.SaveChangesAsync();
    }

    // ── 1. Enrolled count ignores Pending, Dropped, and Withdrawn ─────────────

    [Fact]
    public async Task GetClass_EnrolledCount_IgnoresPendingDroppedWithdrawn_OnlyCountsEnrolled()
    {
        // Arrange — one class with four study loads: one of each status
        var (_, classId, _) = await SeedClassAsync();
        var s1 = Guid.NewGuid();
        var s2 = Guid.NewGuid();
        var s3 = Guid.NewGuid();
        var s4 = Guid.NewGuid();

        await SeedStudyLoadAsync(s1, classId, StudyLoadStatus.Enrolled);
        await SeedStudyLoadAsync(s2, classId, StudyLoadStatus.Pending);
        await SeedStudyLoadAsync(s3, classId, StudyLoadStatus.Dropped);
        await SeedStudyLoadAsync(s4, classId, StudyLoadStatus.Withdrawn);

        // Act
        var classDto = await _classService.GetByIdAsync(classId);

        // Assert — only the single Enrolled row is counted
        Assert.NotNull(classDto);
        Assert.Equal(1, classDto!.EnrolledCount);
    }

    // ── 2. Grade submission rejects Pending, Dropped, and Withdrawn loads ─────

    [Fact]
    public async Task SubmitGrade_PendingLoad_ThrowsWithClearMessage()
    {
        var (_, classId, _) = await SeedClassAsync();
        await SeedTeacherAsync();
        await AssignTeacherToClassAsync(classId);
        var studentId = await SeedStudentUserAsync("pending1");

        var sl = await SeedStudyLoadAsync(studentId, classId, StudyLoadStatus.Pending);
        var dto = new SubmitGradeDto { StudyLoadId = sl.StudyLoadID, MidtermGrade = 85.0m };

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _gradeService.SubmitGradeAsync(dto, _teacherId));
        Assert.Contains("Pending", ex.Message);
    }

    [Fact]
    public async Task SubmitGrade_DroppedLoad_ThrowsWithClearMessage()
    {
        var (_, classId, _) = await SeedClassAsync("IT102");
        await SeedTeacherAsync();
        await AssignTeacherToClassAsync(classId);
        var studentId = await SeedStudentUserAsync("dropped1");

        var sl = await SeedStudyLoadAsync(studentId, classId, StudyLoadStatus.Dropped);
        var dto = new SubmitGradeDto { StudyLoadId = sl.StudyLoadID, MidtermGrade = 85.0m };

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _gradeService.SubmitGradeAsync(dto, _teacherId));
        Assert.Contains("Dropped", ex.Message);
    }

    [Fact]
    public async Task SubmitGrade_WithdrawnLoad_ThrowsWithClearMessage()
    {
        var (_, classId, _) = await SeedClassAsync("IT103");
        await SeedTeacherAsync();
        await AssignTeacherToClassAsync(classId);
        var studentId = await SeedStudentUserAsync("withdrawn1");

        var sl = await SeedStudyLoadAsync(studentId, classId, StudyLoadStatus.Withdrawn);
        var dto = new SubmitGradeDto { StudyLoadId = sl.StudyLoadID, MidtermGrade = 85.0m };

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _gradeService.SubmitGradeAsync(dto, _teacherId));
        Assert.Contains("Withdrawn", ex.Message);
    }

    /// <summary>
    /// Batch grade: a Pending item fails only that student — the whole batch is NOT rejected.
    /// </summary>
    [Fact]
    public async Task SubmitGradeBatch_OnePendingOneEnrolled_OnlyPendingFails_OtherSucceeds()
    {
        var (_, classId, _) = await SeedClassAsync("IT104");
        await SeedTeacherAsync();
        await AssignTeacherToClassAsync(classId);

        // Both study loads must belong to the same class for the batch pre-check to pass
        var enrolledStudentId = await SeedStudentUserAsync("batch-enrolled");
        var pendingStudentId  = await SeedStudentUserAsync("batch-pending");
        var enrolledLoad = await SeedStudyLoadAsync(enrolledStudentId, classId, StudyLoadStatus.Enrolled);
        var pendingLoad  = await SeedStudyLoadAsync(pendingStudentId,  classId, StudyLoadStatus.Pending);

        var batchDto = new SubmitGradeBatchDto
        {
            ClassId = classId,
            Grades =
            [
                new SubmitGradeBatchItemDto { StudyLoadId = enrolledLoad.StudyLoadID, MidtermGrade = 88.0m },
                new SubmitGradeBatchItemDto { StudyLoadId = pendingLoad.StudyLoadID,  MidtermGrade = 88.0m },
            ]
        };

        var result = await _gradeService.SubmitGradeBatchAsync(batchDto, _teacherId);

        Assert.Single(result.Succeeded);
        Assert.Single(result.Failed);
        Assert.Equal(enrolledLoad.StudyLoadID, result.Succeeded[0].StudyLoadId);
        Assert.Equal(pendingLoad.StudyLoadID, result.Failed[0].StudyLoadId);
        Assert.Contains("Pending", result.Failed[0].Reason);
    }

    // ── 3. Duplicate check: Pending load blocks re-enrollment in same class ───

    [Fact]
    public async Task EnrollSingleAsync_PendingLoadExists_DuplicateIsBlocked_ReturnsSameLoad()
    {
        var (_, classId, termId) = await SeedClassAsync();
        var studentId = Guid.NewGuid();

        _context.Users.Add(new User
        {
            UserID = studentId,
            FirebaseUID = "fb-" + Guid.NewGuid(),
            Email = "dup@test.com",
            Role = 5,
            IsActive = true
        });
        _context.GradeClearances.Add(new GradeClearance
        {
            ClearanceID = Guid.NewGuid(),
            UserID = studentId,
            TermID = termId,
            IsCleared = true,
            ClearedAt = DateTime.UtcNow
        });
        var existingPending = await SeedStudyLoadAsync(studentId, classId, StudyLoadStatus.Pending);
        await _context.SaveChangesAsync();

        var dto = new EnrollSingleRequestDto { UserId = studentId, ClassId = classId, Force = false };
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Returns existing load; still only one row in the table
        Assert.True(result.Success);
        Assert.Equal(existingPending.StudyLoadID, result.StudyLoadId);
        var count = await _context.StudyLoads.CountAsync(sl => sl.UserID == studentId && sl.ClassID == classId);
        Assert.Equal(1, count);
    }

    // ── 4. Schedule conflict: Pending load conflicts with new enrollment ───────

    [Fact]
    public async Task EnrollSingleAsync_ConflictsWithPendingLoad_ScheduleWarningReturned()
    {
        var (_, class1Id, termId) = await SeedClassAsync("IT101", "BSIT-1A");
        var (_, class2Id, _)     = await SeedClassAsync("IT102", "BSIT-1B", "2025-2026", 1);

        // Put both classes in the same term
        var class2 = await _context.Classes.FindAsync(class2Id);
        class2!.TermID = termId;
        await _context.SaveChangesAsync();

        var studentId = Guid.NewGuid();
        _context.Users.Add(new User
        {
            UserID = studentId,
            FirebaseUID = "fb-" + Guid.NewGuid(),
            Email = "conflict@test.com",
            Role = 5,
            IsActive = true
        });

        // class1: Pending load, MWF 08:00-09:30
        _context.ClassSchedules.Add(new ClassSchedule
        {
            ScheduleID = Guid.NewGuid(),
            ClassID = class1Id,
            DaysOfWeek = "MWF",
            StartTime = new TimeOnly(8, 0),
            EndTime = new TimeOnly(9, 30),
            Room = "Room 101"
        });

        // class2: overlapping MWF 08:00-09:00 — the enrollment target
        _context.ClassSchedules.Add(new ClassSchedule
        {
            ScheduleID = Guid.NewGuid(),
            ClassID = class2Id,
            DaysOfWeek = "MWF",
            StartTime = new TimeOnly(8, 0),
            EndTime = new TimeOnly(9, 0),
            Room = "Room 102"
        });

        await _context.SaveChangesAsync();
        await SeedStudyLoadAsync(studentId, class1Id, StudyLoadStatus.Pending);

        var dto = new EnrollSingleRequestDto { UserId = studentId, ClassId = class2Id, Force = false };
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Conflict should be flagged
        Assert.False(result.Success);
        Assert.Contains(result.Warnings, w => w.Contains("conflict", StringComparison.OrdinalIgnoreCase));
    }

    // ── 5. Prior-term clearance: Pending/Dropped loads do NOT create a hold ───

    [Fact]
    public async Task EnrollSingleAsync_PriorTermOnlyPendingLoads_NoClearanceHold()
    {
        var (_, priorClassId, _) = await SeedClassAsync("IT001", "BSIT-0A", "2024-2025", 1);
        var (_, newClassId, _)   = await SeedClassAsync("IT101", "BSIT-1A", "2025-2026", 1);

        var studentId = Guid.NewGuid();
        _context.Users.Add(new User
        {
            UserID = studentId,
            FirebaseUID = "fb-" + Guid.NewGuid(),
            Email = "priorpending@test.com",
            Role = 5,
            IsActive = true
        });
        await SeedStudyLoadAsync(studentId, priorClassId, StudyLoadStatus.Pending,
            createdAt: DateTime.UtcNow.AddDays(-90));
        await _context.SaveChangesAsync();

        var dto = new EnrollSingleRequestDto { UserId = studentId, ClassId = newClassId, Force = false };
        // Should NOT throw "unresolved clearance hold"
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);
        Assert.True(result.Success);
    }

    [Fact]
    public async Task EnrollSingleAsync_PriorTermOnlyDroppedLoad_NoClearanceHold()
    {
        var (_, priorClassId, _) = await SeedClassAsync("IT001", "BSIT-0A", "2024-2025", 1);
        var (_, newClassId, _)   = await SeedClassAsync("IT101", "BSIT-1A", "2025-2026", 1);

        var studentId = Guid.NewGuid();
        _context.Users.Add(new User
        {
            UserID = studentId,
            FirebaseUID = "fb-" + Guid.NewGuid(),
            Email = "priordropped@test.com",
            Role = 5,
            IsActive = true
        });
        await SeedStudyLoadAsync(studentId, priorClassId, StudyLoadStatus.Dropped,
            createdAt: DateTime.UtcNow.AddDays(-90));
        await _context.SaveChangesAsync();

        var dto = new EnrollSingleRequestDto { UserId = studentId, ClassId = newClassId, Force = false };
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);
        Assert.True(result.Success);
    }

    // ── 6. PATCH status endpoint DTO: Pending (4) rejected; 1-3 pass ──────────

    [Fact]
    public void UpdateStudyLoadStatusDto_PendingValue4_FailsValidation_WithExplicitMessage()
    {
        var dto = new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Pending };

        var results = new List<System.ComponentModel.DataAnnotations.ValidationResult>();
        var ctx = new System.ComponentModel.DataAnnotations.ValidationContext(dto);
        bool isValid = System.ComponentModel.DataAnnotations.Validator
            .TryValidateObject(dto, ctx, results, validateAllProperties: true);

        Assert.False(isValid);
        Assert.Single(results);
        Assert.Contains("Pending (4) cannot be set via this endpoint", results[0].ErrorMessage);
    }

    [Theory]
    [InlineData(StudyLoadStatus.Enrolled)]
    [InlineData(StudyLoadStatus.Dropped)]
    [InlineData(StudyLoadStatus.Withdrawn)]
    public void UpdateStudyLoadStatusDto_ValidValues1To3_PassValidation(int status)
    {
        var dto = new UpdateStudyLoadStatusDto { LoadStatus = status };

        var results = new List<System.ComponentModel.DataAnnotations.ValidationResult>();
        var ctx = new System.ComponentModel.DataAnnotations.ValidationContext(dto);
        bool isValid = System.ComponentModel.DataAnnotations.Validator
            .TryValidateObject(dto, ctx, results, validateAllProperties: true);

        Assert.True(isValid);
        Assert.Empty(results);
    }

    [Fact]
    public async Task UpdateStatusAsync_ServiceRejectsPending_CannotBeSetViaEndpoint()
    {
        // Service now throws when newStatus == Pending so the endpoint is guarded at service level too.
        var (_, classId, _) = await SeedClassAsync();
        var studentId = Guid.NewGuid();
        _context.Users.Add(new User
        {
            UserID = studentId,
            FirebaseUID = "fb-" + Guid.NewGuid(),
            Email = "setpending@test.com",
            Role = 5,
            IsActive = true
        });
        var sl = await SeedStudyLoadAsync(studentId, classId, StudyLoadStatus.Enrolled);
        await _context.SaveChangesAsync();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _studyLoadService.UpdateStatusAsync(sl.StudyLoadID, StudyLoadStatus.Pending));
    }

    // ── 7. StudyLoadStatus display text for all four values ───────────────────

    [Theory]
    [InlineData(StudyLoadStatus.Enrolled,  "Enrolled")]
    [InlineData(StudyLoadStatus.Dropped,   "Dropped")]
    [InlineData(StudyLoadStatus.Withdrawn, "Withdrawn")]
    [InlineData(StudyLoadStatus.Pending,   "Pending")]
    public void StudyLoadStatus_GetDisplayText_AllFourValues(int status, string expected)
    {
        Assert.Equal(expected, StudyLoadStatus.GetDisplayText(status));
    }

    [Fact]
    public void StudyLoadStatus_GetDisplayText_UnknownValue_ReturnsStatusN()
    {
        Assert.Equal("Status 99", StudyLoadStatus.GetDisplayText(99));
    }

    [Fact]
    public void StudyLoadStatus_IsValid_AcceptsAll4_RejectsOutOfRange()
    {
        Assert.True(StudyLoadStatus.IsValid(StudyLoadStatus.Enrolled));
        Assert.True(StudyLoadStatus.IsValid(StudyLoadStatus.Dropped));
        Assert.True(StudyLoadStatus.IsValid(StudyLoadStatus.Withdrawn));
        Assert.True(StudyLoadStatus.IsValid(StudyLoadStatus.Pending));
        Assert.True(StudyLoadStatus.IsValid(StudyLoadStatus.Rejected));  // now valid
        Assert.False(StudyLoadStatus.IsValid(0));
        Assert.False(StudyLoadStatus.IsValid(6));
    }

    // ── 8. Roster retrieval by class: Teacher vs Staff pending visibility ──────

    [Fact]
    public async Task GetByClassAsync_ExcludePendingTrue_OmitsPendingLoads()
    {
        var (_, classId, _) = await SeedClassAsync("IT105");
        var s1 = await SeedStudentUserAsync("roster-enrolled");
        var s2 = await SeedStudentUserAsync("roster-pending");
        var s3 = await SeedStudentUserAsync("roster-dropped");

        await SeedStudyLoadAsync(s1, classId, StudyLoadStatus.Enrolled);
        await SeedStudyLoadAsync(s2, classId, StudyLoadStatus.Pending);
        await SeedStudyLoadAsync(s3, classId, StudyLoadStatus.Dropped);

        // Caller is Teacher: excludePending = true
        var results = await _studyLoadService.GetByClassAsync(classId, excludePending: true);

        Assert.Equal(2, results.Count);
        Assert.DoesNotContain(results, r => r.LoadStatus == "Pending");
        Assert.Contains(results, r => r.LoadStatus == "Enrolled");
        Assert.Contains(results, r => r.LoadStatus == "Dropped");
    }

    [Fact]
    public async Task GetByClassAsync_ExcludePendingFalse_ReturnsAllLoadsIncludingPending()
    {
        var (_, classId, _) = await SeedClassAsync("IT106");
        var s1 = await SeedStudentUserAsync("staff-roster-enrolled");
        var s2 = await SeedStudentUserAsync("staff-roster-pending");
        var s3 = await SeedStudentUserAsync("staff-roster-dropped");

        await SeedStudyLoadAsync(s1, classId, StudyLoadStatus.Enrolled);
        await SeedStudyLoadAsync(s2, classId, StudyLoadStatus.Pending);
        await SeedStudyLoadAsync(s3, classId, StudyLoadStatus.Dropped);

        // Caller is Registrar/Admin/ProgramHead: excludePending = false
        var results = await _studyLoadService.GetByClassAsync(classId, excludePending: false);

        Assert.Equal(3, results.Count);
        Assert.Contains(results, r => r.LoadStatus == "Pending");
        Assert.Contains(results, r => r.LoadStatus == "Enrolled");
        Assert.Contains(results, r => r.LoadStatus == "Dropped");
    }
}
