using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Tests verifying prerequisite validation behavior in StudyLoadService.
/// Stage 1: Documents what EnrollSingleAsync and EnrollBatchAsync do TODAY
/// before the Stage 3 shared validation overhaul.
/// </summary>
public class StudyLoadServicePrerequisiteTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly StudyLoadRepository _studyLoadRepo;
    private readonly GradeClearanceRepository _clearanceRepo;
    private readonly GradeClearanceService _clearanceService;
    private readonly StudyLoadService _studyLoadService;

    private readonly Guid _registrarId = Guid.NewGuid();
    private readonly Guid _teacherId = Guid.NewGuid();

    public StudyLoadServicePrerequisiteTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _studyLoadRepo = new StudyLoadRepository(_context);
        _clearanceRepo = new GradeClearanceRepository(_context);
        _clearanceService = new GradeClearanceService(_context, _clearanceRepo);
        _studyLoadService = new StudyLoadService(_context, _studyLoadRepo, _clearanceService, NullLogger<StudyLoadService>.Instance);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    // ── Fixture Helpers ────────────────────────────────────────────────────────

    private async Task<User> CreateStudentAsync()
    {
        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-" + Guid.NewGuid(),
            Email = $"student-{Guid.NewGuid():N}@dbtc-cebu.edu.ph",
            Role = 5,
            IsActive = true
        };
        _context.Users.Add(student);
        await _context.SaveChangesAsync();
        return student;
    }

    private async Task<AcademicTerm> CreateTermAsync(string schoolYear, int semester)
    {
        var term = new AcademicTerm
        {
            TermID = Guid.NewGuid(),
            SchoolYear = schoolYear,
            Semester = semester,
            IsActive = true
        };
        _context.AcademicTerms.Add(term);
        await _context.SaveChangesAsync();
        return term;
    }

    private async Task<Subject> CreateSubjectAsync(string code, string title)
    {
        var subject = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = code,
            SubjectTitle = title,
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3.0m,
            LabUnits = 0.0m
        };
        _context.Subjects.Add(subject);
        await _context.SaveChangesAsync();
        return subject;
    }

    private async Task AddPrerequisiteAsync(Guid subjectId, Guid prerequisiteSubjectId, int requisiteType = 0)
    {
        _context.SubjectPrerequisites.Add(new SubjectPrerequisite
        {
            PrerequisiteID = Guid.NewGuid(),
            SubjectID = subjectId,
            PrerequisiteSubjectID = prerequisiteSubjectId,
            RequisiteType = requisiteType
        });
        await _context.SaveChangesAsync();
    }

    private async Task<Class> CreateClassAsync(Subject subject, AcademicTerm term, string className)
    {
        var cls = new Class
        {
            ClassID = Guid.NewGuid(),
            ClassName = className,
            SubjectID = subject.SubjectID,
            TermID = term.TermID,
            CreatedAt = DateTime.UtcNow
        };
        _context.Classes.Add(cls);
        await _context.SaveChangesAsync();
        return cls;
    }

    /// <summary>
    /// Helper to seed a completed study load and grade for a prior term,
    /// along with a cleared grade clearance so prior-term checks don't block enrollment.
    /// </summary>
    private async Task SeedGradeAsync(Guid userId, Class cls, int remarks, int loadStatus = 1)
    {
        var studyLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = userId,
            ClassID = cls.ClassID,
            LoadStatus = loadStatus,
            CreatedAt = DateTime.UtcNow.AddDays(-60)
        };
        _context.StudyLoads.Add(studyLoad);

        var grade = new Grade
        {
            GradeID = Guid.NewGuid(),
            StudyLoadID = studyLoad.StudyLoadID,
            SubmittedByUserID = _teacherId,
            MidtermGrade = 85.0m,
            FinalGrade = remarks == 1 ? 88.0m : 65.0m,
            Remarks = remarks,
            DateSubmitted = DateTime.UtcNow.AddDays(-30)
        };
        _context.Grades.Add(grade);

        // Ensure clearance for this prior term so ValidatePriorTermClearanceAsync passes
        var clearance = await _context.GradeClearances
            .FirstOrDefaultAsync(gc => gc.UserID == userId && gc.TermID == cls.TermID);
        if (clearance == null)
        {
            _context.GradeClearances.Add(new GradeClearance
            {
                ClearanceID = Guid.NewGuid(),
                UserID = userId,
                TermID = cls.TermID,
                IsCleared = true,
                ClearedAt = DateTime.UtcNow.AddDays(-20)
            });
        }
        else
        {
            clearance.IsCleared = true;
        }

        await _context.SaveChangesAsync();
    }

    private async Task<StudyLoad> SeedStudyLoadAsync(Guid userId, Class cls, int loadStatus, DateTime? createdAt = null)
    {
        var studyLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = userId,
            ClassID = cls.ClassID,
            LoadStatus = loadStatus,
            CreatedAt = createdAt ?? DateTime.UtcNow
        };
        _context.StudyLoads.Add(studyLoad);
        await _context.SaveChangesAsync();
        return studyLoad;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    /// <summary>
    /// 1. Passed prerequisite: When a student has a Passed grade (Remarks=1) in the
    /// prerequisite subject, EnrollSingleAsync enrolls them successfully.
    /// </summary>
    [Fact]
    public async Task EnrollSingleAsync_PassedPrerequisite_EnrollsSuccessfully()
    {
        // Arrange
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var term2 = await CreateTermAsync("2025-2026", 2);

        var prereqSubject = await CreateSubjectAsync("MATH101", "College Algebra");
        var targetSubject = await CreateSubjectAsync("MATH102", "Trigonometry");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var prereqClass = await CreateClassAsync(prereqSubject, term1, "MATH101-Section1");
        var targetClass = await CreateClassAsync(targetSubject, term2, "MATH102-Section1");

        // Seed Passed grade (Remarks=1) for prerequisite
        await SeedGradeAsync(student.UserID, prereqClass, remarks: 1);

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = false
        };

        // Act
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Assert
        Assert.True(result.Success);
        Assert.NotNull(result.StudyLoadId);
        Assert.Empty(result.Warnings);

        var createdLoad = await _context.StudyLoads.FindAsync(result.StudyLoadId);
        Assert.NotNull(createdLoad);
        Assert.Equal(student.UserID, createdLoad.UserID);
        Assert.Equal(targetClass.ClassID, createdLoad.ClassID);
        Assert.Equal(1, createdLoad.LoadStatus); // Enrolled
    }

    /// <summary>
    /// 2. No grade for prerequisite: When a student has never taken or has no grade
    /// for the prerequisite, EnrollSingleAsync returns Success=false with a
    /// "Prerequisite not met" warning.
    /// </summary>
    [Fact]
    public async Task EnrollSingleAsync_NoGradeForPrerequisite_BlockedWithWarning()
    {
        // Arrange
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);

        var prereqSubject = await CreateSubjectAsync("MATH101", "College Algebra");
        var targetSubject = await CreateSubjectAsync("MATH102", "Trigonometry");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var targetClass = await CreateClassAsync(targetSubject, term, "MATH102-Section1");

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = false
        };

        // Act
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Assert
        Assert.False(result.Success);
        Assert.Null(result.StudyLoadId);
        Assert.Single(result.Warnings);
        Assert.Contains("Prerequisite not met: MATH101", result.Warnings[0]);

        var count = await _context.StudyLoads.CountAsync(sl => sl.UserID == student.UserID && sl.ClassID == targetClass.ClassID);
        Assert.Equal(0, count);
    }

    /// <summary>
    /// 3. Failed prerequisite (Remarks=2): When a student failed the prerequisite subject,
    /// EnrollSingleAsync returns Success=false and blocks enrollment.
    /// </summary>
    [Fact]
    public async Task EnrollSingleAsync_FailedPrerequisite_BlockedWithWarning()
    {
        // Arrange
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var term2 = await CreateTermAsync("2025-2026", 2);

        var prereqSubject = await CreateSubjectAsync("MATH101", "College Algebra");
        var targetSubject = await CreateSubjectAsync("MATH102", "Trigonometry");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var prereqClass = await CreateClassAsync(prereqSubject, term1, "MATH101-Section1");
        var targetClass = await CreateClassAsync(targetSubject, term2, "MATH102-Section1");

        // Seed Failed grade (Remarks=2) for prerequisite
        await SeedGradeAsync(student.UserID, prereqClass, remarks: 2);

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = false
        };

        // Act
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Assert
        Assert.False(result.Success);
        Assert.Null(result.StudyLoadId);
        Assert.Single(result.Warnings);
        Assert.Contains("Prerequisite not met: MATH101", result.Warnings[0]);

        var count = await _context.StudyLoads.CountAsync(sl => sl.UserID == student.UserID && sl.ClassID == targetClass.ClassID);
        Assert.Equal(0, count);
    }

    /// <summary>
    /// 4. Failed then Passed on retake: When a student previously failed the prerequisite
    /// but retook it in another class and Passed (Remarks=1), the later Passed grade
    /// satisfies the prerequisite and allows enrollment.
    /// </summary>
    [Fact]
    public async Task EnrollSingleAsync_FailedThenPassedOnRetake_EnrollsSuccessfully()
    {
        // Arrange
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2024-2025", 1);
        var term2 = await CreateTermAsync("2024-2025", 2);
        var term3 = await CreateTermAsync("2025-2026", 1);

        var prereqSubject = await CreateSubjectAsync("MATH101", "College Algebra");
        var targetSubject = await CreateSubjectAsync("MATH102", "Trigonometry");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var firstAttemptClass = await CreateClassAsync(prereqSubject, term1, "MATH101-FirstAttempt");
        var retakeClass = await CreateClassAsync(prereqSubject, term2, "MATH101-Retake");
        var targetClass = await CreateClassAsync(targetSubject, term3, "MATH102-Section1");

        // Attempt 1: Failed
        await SeedGradeAsync(student.UserID, firstAttemptClass, remarks: 2);
        // Attempt 2: Passed on retake
        await SeedGradeAsync(student.UserID, retakeClass, remarks: 1);

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = false
        };

        // Act
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Assert
        Assert.True(result.Success);
        Assert.NotNull(result.StudyLoadId);
        Assert.Empty(result.Warnings);

        var count = await _context.StudyLoads.CountAsync(sl => sl.UserID == student.UserID && sl.ClassID == targetClass.ClassID);
        Assert.Equal(1, count);
    }

    /// <summary>
    /// 5. Retaking the failed subject itself: A student who previously failed a subject
    /// is allowed to enroll in a new section of that same subject to retake it.
    /// </summary>
    [Fact]
    public async Task EnrollSingleAsync_RetakingFailedSubjectItself_Allowed()
    {
        // Arrange
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2024-2025", 1);
        var term2 = await CreateTermAsync("2024-2025", 2);

        var subject = await CreateSubjectAsync("MATH101", "College Algebra");
        var failedClass = await CreateClassAsync(subject, term1, "MATH101-Fall");
        var retakeClass = await CreateClassAsync(subject, term2, "MATH101-Spring");

        // Student failed first attempt
        await SeedGradeAsync(student.UserID, failedClass, remarks: 2);

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = retakeClass.ClassID,
            Force = false
        };

        // Act
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Assert
        Assert.True(result.Success);
        Assert.NotNull(result.StudyLoadId);
        Assert.Empty(result.Warnings);

        var retakeLoad = await _context.StudyLoads.FindAsync(result.StudyLoadId);
        Assert.NotNull(retakeLoad);
        Assert.Equal(retakeClass.ClassID, retakeLoad.ClassID);
    }

    /// <summary>
    /// 6. Force=true bypasses prerequisite warning: When Force=true is specified,
    /// EnrollSingleAsync enrolls the student even if the prerequisite is unmet,
    /// returning Success=true with the warning preserved.
    /// </summary>
    [Fact]
    public async Task EnrollSingleAsync_ForceTrue_BypassesPrerequisiteWarning()
    {
        // Arrange
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var term2 = await CreateTermAsync("2025-2026", 2);

        var prereqSubject = await CreateSubjectAsync("MATH101", "College Algebra");
        var targetSubject = await CreateSubjectAsync("MATH102", "Trigonometry");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var prereqClass = await CreateClassAsync(prereqSubject, term1, "MATH101-Section1");
        var targetClass = await CreateClassAsync(targetSubject, term2, "MATH102-Section1");

        // Student failed prerequisite
        await SeedGradeAsync(student.UserID, prereqClass, remarks: 2);

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = true,
            ForceReason = "Per department head approval"
        };

        // Act
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Assert
        Assert.True(result.Success);
        Assert.NotNull(result.StudyLoadId);
        Assert.Single(result.Warnings);
        Assert.Contains("Prerequisite not met: MATH101", result.Warnings[0]);

        var createdLoad = await _context.StudyLoads.FindAsync(result.StudyLoadId);
        Assert.NotNull(createdLoad);
        Assert.Equal(targetClass.ClassID, createdLoad.ClassID);
        Assert.True(createdLoad.IsForced);
        Assert.Equal(_registrarId, createdLoad.ForcedByUserID);
        Assert.Equal("Per department head approval", createdLoad.ForcedReason);
    }

    /// <summary>
    /// 7. EnrollBatchAsync with unmet prerequisite: Skips the class and returns per-class reason.
    /// </summary>
    [Fact]
    public async Task EnrollBatchAsync_UnmetPrerequisite_IsSkipped_ReturnsPerClassReason()
    {
        // Arrange
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);

        var prereqSubject = await CreateSubjectAsync("MATH101", "College Algebra");
        var targetSubject = await CreateSubjectAsync("MATH102", "Trigonometry");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var targetClass = await CreateClassAsync(targetSubject, term, "MATH102-Section1");

        // Student has NO grade for MATH101
        var dto = new EnrollBatchRequestDto
        {
            UserId = student.UserID,
            TermId = term.TermID,
            ClassIds = [targetClass.ClassID]
        };

        // Act
        var results = await _studyLoadService.EnrollBatchAsync(dto, _registrarId);

        // Assert: Class is skipped with reasons
        Assert.Single(results);
        Assert.Equal(targetClass.ClassID, results[0].ClassId);
        Assert.False(results[0].Enrolled);
        Assert.Null(results[0].StudyLoadId);
        Assert.Single(results[0].Reasons);
        Assert.Contains("Prerequisite not met: MATH101", results[0].Reasons[0]);

        var count = await _context.StudyLoads.CountAsync(sl => sl.UserID == student.UserID && sl.ClassID == targetClass.ClassID);
        Assert.Equal(0, count);
    }

    /// <summary>
    /// 8. Passed grade on a Dropped StudyLoad is NOT evidence of completing the prerequisite.
    /// Enrollment in dependent class is blocked with warning.
    /// </summary>
    [Fact]
    public async Task EnrollSingleAsync_PassedGradeOnDroppedStudyLoad_BlockedWithWarning()
    {
        // Arrange
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var term2 = await CreateTermAsync("2025-2026", 2);

        var prereqSubject = await CreateSubjectAsync("MATH101", "College Algebra");
        var targetSubject = await CreateSubjectAsync("MATH102", "Trigonometry");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var prereqClass = await CreateClassAsync(prereqSubject, term1, "MATH101-Section1");
        var targetClass = await CreateClassAsync(targetSubject, term2, "MATH102-Section1");

        // Seed Passed grade (Remarks=1), but on a DROPPED study load (LoadStatus=2)
        await SeedGradeAsync(student.UserID, prereqClass, remarks: 1, loadStatus: 2);

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = false
        };

        // Act
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Assert: Blocked because dropped load is not evidence
        Assert.False(result.Success);
        Assert.Null(result.StudyLoadId);
        Assert.Single(result.Warnings);
        Assert.Contains("Prerequisite not met: MATH101", result.Warnings[0]);
        Assert.Contains("dropped or withdrawn", result.Warnings[0]);

        var count = await _context.StudyLoads.CountAsync(sl => sl.UserID == student.UserID && sl.ClassID == targetClass.ClassID);
        Assert.Equal(0, count);
    }

    /// <summary>
    /// 9. Pending load for prerequisite in earlier term is NOT evidence:
    /// Only StudyLoads with LoadStatus == Enrolled count as evidence for a prerequisite
    /// (either a Passed grade, or in-progress meaning enrolled with no final grade).
    /// A Pending load for a prerequisite subject in an earlier term does NOT count as evidence
    /// and must NOT satisfy the prerequisite (must not be reported as PREREQUISITE_IN_PROGRESS).
    /// Enrollment in the dependent subject is blocked with a warning.
    /// </summary>
    [Fact]
    public async Task EnrollSingleAsync_PendingLoadForPrerequisiteInEarlierTerm_DoesNotCountAsEvidence_BlockedWithWarning()
    {
        // Arrange
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var term2 = await CreateTermAsync("2025-2026", 2);

        var prereqSubject = await CreateSubjectAsync("MATH101", "College Algebra");
        var targetSubject = await CreateSubjectAsync("MATH102", "Trigonometry");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var prereqClass = await CreateClassAsync(prereqSubject, term1, "MATH101-Section1");
        var targetClass = await CreateClassAsync(targetSubject, term2, "MATH102-Section1");

        // Seed a PENDING study load (LoadStatus=4) in earlier term for prerequisite, with NO grade
        await SeedStudyLoadAsync(student.UserID, prereqClass, loadStatus: StudyLoadStatus.Pending, createdAt: DateTime.UtcNow.AddDays(-60));

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = false
        };

        // Act
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Assert: Pending load in earlier term is NOT evidence; prerequisite is not met
        Assert.False(result.Success);
        Assert.Null(result.StudyLoadId);
        Assert.Single(result.Warnings);
        Assert.Contains("Prerequisite not met: MATH101", result.Warnings[0]);

        var count = await _context.StudyLoads.CountAsync(sl => sl.UserID == student.UserID && sl.ClassID == targetClass.ClassID);
        Assert.Equal(0, count);
    }

    /// <summary>
    /// 10. Pending load in the same term for the same SubjectID counts as SAME_SUBJECT_THIS_TERM.
    /// Attempting to enroll in another section of the same subject in the same term is blocked.
    /// </summary>
    [Fact]
    public async Task EnrollSingleAsync_PendingLoadForSameSubjectThisTerm_DifferentSection_BlockedWithWarning()
    {
        // Arrange
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);

        var subject = await CreateSubjectAsync("MATH101", "College Algebra");
        var sectionA = await CreateClassAsync(subject, term, "MATH101-SectionA");
        var sectionB = await CreateClassAsync(subject, term, "MATH101-SectionB");

        // Seed Pending load in section A of MATH101 in this term
        await SeedStudyLoadAsync(student.UserID, sectionA, loadStatus: StudyLoadStatus.Pending);

        // Attempt to enroll in section B of the SAME subject in the SAME term
        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = sectionB.ClassID,
            Force = false
        };

        // Act
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Assert: Blocked by SAME_SUBJECT_THIS_TERM
        Assert.False(result.Success);
        Assert.Null(result.StudyLoadId);
        Assert.Single(result.Warnings);
        Assert.Contains("SAME_SUBJECT_THIS_TERM", result.Warnings[0]);

        var count = await _context.StudyLoads.CountAsync(sl => sl.UserID == student.UserID && sl.ClassID == sectionB.ClassID);
        Assert.Equal(0, count);
    }

    // ── Stage 3 New Tests ─────────────────────────────────────────────────────

    [Fact]
    public async Task ValidateEnrollmentRulesAsync_PrerequisiteNotTaken_ReturnsCorrectFinding()
    {
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);
        var prereq = await CreateSubjectAsync("CS101", "Intro to CS");
        var target = await CreateSubjectAsync("CS102", "Data Structures");
        await AddPrerequisiteAsync(target.SubjectID, prereq.SubjectID);
        var targetClass = await CreateClassAsync(target, term, "CS102-A");

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, targetClass.ClassID, term.TermID);

        Assert.Single(findings);
        Assert.Equal(EnrollmentRuleCodes.PrerequisiteNotTaken, findings[0].Code);
        Assert.Contains("never taken", findings[0].Message);
        Assert.Equal(prereq.SubjectID, findings[0].SubjectId);
    }

    [Fact]
    public async Task ValidateEnrollmentRulesAsync_PrerequisiteFailed_ReturnsFindingWithGrade()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2024-2025", 1);
        var term2 = await CreateTermAsync("2025-2026", 1);
        var prereq = await CreateSubjectAsync("CS101", "Intro to CS");
        var target = await CreateSubjectAsync("CS102", "Data Structures");
        await AddPrerequisiteAsync(target.SubjectID, prereq.SubjectID);

        var prereqClass = await CreateClassAsync(prereq, term1, "CS101-A");
        var targetClass = await CreateClassAsync(target, term2, "CS102-A");

        // Seed failed grade with 65.0 final grade
        await SeedGradeAsync(student.UserID, prereqClass, remarks: 2, loadStatus: 1);

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, targetClass.ClassID, term2.TermID);

        Assert.Single(findings);
        Assert.Equal(EnrollmentRuleCodes.PrerequisiteFailed, findings[0].Code);
        Assert.Contains("failed, last grade 65.0", findings[0].Message);
    }

    [Fact]
    public async Task ValidateEnrollmentRulesAsync_PrerequisiteInProgress_ReturnsCorrectFinding()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var prereq = await CreateSubjectAsync("CS101", "Intro to CS");
        var target = await CreateSubjectAsync("CS102", "Data Structures");
        await AddPrerequisiteAsync(target.SubjectID, prereq.SubjectID);

        var prereqClass = await CreateClassAsync(prereq, term1, "CS101-A");
        var targetClass = await CreateClassAsync(target, term1, "CS102-A");

        // Seed enrolled load with no grade encoded
        await SeedStudyLoadAsync(student.UserID, prereqClass, StudyLoadStatus.Enrolled);

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, targetClass.ClassID, term1.TermID);

        Assert.Single(findings);
        Assert.Equal(EnrollmentRuleCodes.PrerequisiteInProgress, findings[0].Code);
        Assert.Contains("grade not yet encoded", findings[0].Message);
    }

    [Fact]
    public async Task ValidateEnrollmentRulesAsync_PrerequisiteDropped_ReturnsCorrectFinding()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var prereq = await CreateSubjectAsync("CS101", "Intro to CS");
        var target = await CreateSubjectAsync("CS102", "Data Structures");
        await AddPrerequisiteAsync(target.SubjectID, prereq.SubjectID);

        var prereqClass = await CreateClassAsync(prereq, term1, "CS101-A");
        var targetClass = await CreateClassAsync(target, term1, "CS102-A");

        await SeedStudyLoadAsync(student.UserID, prereqClass, StudyLoadStatus.Dropped);

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, targetClass.ClassID, term1.TermID);

        Assert.Single(findings);
        Assert.Equal(EnrollmentRuleCodes.PrerequisiteDropped, findings[0].Code);
        Assert.Contains("dropped or withdrawn", findings[0].Message);
    }

    [Fact]
    public async Task ValidateEnrollmentRulesAsync_AlreadyPassed_ReturnsCorrectFinding()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2024-2025", 1);
        var term2 = await CreateTermAsync("2025-2026", 1);
        var subject = await CreateSubjectAsync("CS101", "Intro to CS");

        var class1 = await CreateClassAsync(subject, term1, "CS101-A");
        var class2 = await CreateClassAsync(subject, term2, "CS101-B");

        // Student already passed in term 1
        await SeedGradeAsync(student.UserID, class1, remarks: 1, loadStatus: 1);

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, class2.ClassID, term2.TermID);

        Assert.Single(findings);
        Assert.Equal(EnrollmentRuleCodes.AlreadyPassed, findings[0].Code);
        Assert.Contains("ALREADY_PASSED", findings[0].Message);
    }

    [Fact]
    public async Task ValidateEnrollmentRulesAsync_SameSubjectThisTerm_ReturnsCorrectFinding()
    {
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);
        var subject = await CreateSubjectAsync("CS101", "Intro to CS");

        var sectionA = await CreateClassAsync(subject, term, "CS101-SectionA");
        var sectionB = await CreateClassAsync(subject, term, "CS101-SectionB");

        await SeedStudyLoadAsync(student.UserID, sectionA, StudyLoadStatus.Enrolled);

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, sectionB.ClassID, term.TermID);

        Assert.Single(findings);
        Assert.Equal(EnrollmentRuleCodes.SameSubjectThisTerm, findings[0].Code);
        Assert.Contains("SAME_SUBJECT_THIS_TERM", findings[0].Message);
    }

    [Fact]
    public async Task ValidateEnrollmentRulesAsync_RetakePassed_ClearsEarlierFailure()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2024-2025", 1);
        var term2 = await CreateTermAsync("2024-2025", 2);
        var term3 = await CreateTermAsync("2025-2026", 1);

        var prereq = await CreateSubjectAsync("MATH101", "Algebra");
        var target = await CreateSubjectAsync("MATH102", "Calculus");
        await AddPrerequisiteAsync(target.SubjectID, prereq.SubjectID);

        var failClass = await CreateClassAsync(prereq, term1, "MATH101-Fall");
        var passClass = await CreateClassAsync(prereq, term2, "MATH101-Spring");
        var targetClass = await CreateClassAsync(target, term3, "MATH102-Section1");

        // Attempt 1: Failed
        await SeedGradeAsync(student.UserID, failClass, remarks: 2, loadStatus: 1);
        // Attempt 2: Passed
        await SeedGradeAsync(student.UserID, passClass, remarks: 1, loadStatus: 1);

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, targetClass.ClassID, term3.TermID);

        Assert.Empty(findings);
    }

    [Fact]
    public async Task ValidateEnrollmentRulesAsync_RetakeInProgress_ReportsInProgress()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2024-2025", 1);
        var term2 = await CreateTermAsync("2025-2026", 1);

        var prereq = await CreateSubjectAsync("MATH101", "Algebra");
        var target = await CreateSubjectAsync("MATH102", "Calculus");
        await AddPrerequisiteAsync(target.SubjectID, prereq.SubjectID);

        var failClass = await CreateClassAsync(prereq, term1, "MATH101-Fall");
        var inProgClass = await CreateClassAsync(prereq, term2, "MATH101-Spring");
        var targetClass = await CreateClassAsync(target, term2, "MATH102-Section1");

        // Attempt 1: Failed
        await SeedGradeAsync(student.UserID, failClass, remarks: 2, loadStatus: 1);
        // Attempt 2: Enrolled in progress (no grade)
        await SeedStudyLoadAsync(student.UserID, inProgClass, StudyLoadStatus.Enrolled);

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, targetClass.ClassID, term2.TermID);

        Assert.Single(findings);
        Assert.Equal(EnrollmentRuleCodes.PrerequisiteInProgress, findings[0].Code);
        Assert.Contains("grade not yet encoded", findings[0].Message);
    }

    [Fact]
    public async Task ValidateEnrollmentRulesAsync_PendingLoadInEarlierTerm_ReportsNotTaken_NotEvidence()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2024-2025", 1);
        var term2 = await CreateTermAsync("2025-2026", 1);

        var prereq = await CreateSubjectAsync("MATH101", "Algebra");
        var target = await CreateSubjectAsync("MATH102", "Calculus");
        await AddPrerequisiteAsync(target.SubjectID, prereq.SubjectID);

        var pendingClass = await CreateClassAsync(prereq, term1, "MATH101-Section1");
        var targetClass = await CreateClassAsync(target, term2, "MATH102-Section1");

        await SeedStudyLoadAsync(student.UserID, pendingClass, StudyLoadStatus.Pending);

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, targetClass.ClassID, term2.TermID);

        Assert.Single(findings);
        Assert.Equal(EnrollmentRuleCodes.PrerequisiteNotTaken, findings[0].Code);
        Assert.Contains("never taken", findings[0].Message);
    }

    [Fact]
    public async Task EnrollSingleAsync_RequisiteTypeCorequisite_DoesNotBlockEnrollment()
    {
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);

        var coreqSubject = await CreateSubjectAsync("PHYS101L", "Physics Lab");
        var targetSubject = await CreateSubjectAsync("PHYS101", "Physics Lecture");
        // RequisiteType = 1 is corequisite (ignored by prerequisite checks)
        await AddPrerequisiteAsync(targetSubject.SubjectID, coreqSubject.SubjectID, requisiteType: 1);

        var targetClass = await CreateClassAsync(targetSubject, term, "PHYS101-Lecture");

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = false
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        Assert.True(result.Success);
        Assert.NotNull(result.StudyLoadId);
        Assert.Empty(result.Warnings);
    }

    [Fact]
    public async Task EnrollBatchAsync_PartialSuccess_EnrollsValidClassAndSkipsInvalidWithReasons()
    {
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);

        var prereq = await CreateSubjectAsync("MATH101", "Algebra");
        var subjectWithPrereq = await CreateSubjectAsync("MATH102", "Calculus");
        await AddPrerequisiteAsync(subjectWithPrereq.SubjectID, prereq.SubjectID);

        var standaloneSubject = await CreateSubjectAsync("ENG101", "Communication");

        var invalidClass = await CreateClassAsync(subjectWithPrereq, term, "MATH102-Sec1");
        var validClass = await CreateClassAsync(standaloneSubject, term, "ENG101-Sec1");

        var dto = new EnrollBatchRequestDto
        {
            UserId = student.UserID,
            TermId = term.TermID,
            ClassIds = [invalidClass.ClassID, validClass.ClassID]
        };

        var results = await _studyLoadService.EnrollBatchAsync(dto, _registrarId);

        Assert.Equal(2, results.Count);

        var invalidResult = results.First(r => r.ClassId == invalidClass.ClassID);
        Assert.False(invalidResult.Enrolled);
        Assert.Null(invalidResult.StudyLoadId);
        Assert.Single(invalidResult.Reasons);
        Assert.Contains("Prerequisite not met: MATH101", invalidResult.Reasons[0]);

        var validResult = results.First(r => r.ClassId == validClass.ClassID);
        Assert.True(validResult.Enrolled);
        Assert.NotNull(validResult.StudyLoadId);
        Assert.Empty(validResult.Reasons);

        // Database only has 1 study load created
        var loads = await _context.StudyLoads.Where(sl => sl.UserID == student.UserID).ToListAsync();
        Assert.Single(loads);
        Assert.Equal(validClass.ClassID, loads[0].ClassID);

        // Grade clearance created for the term
        var clearance = await _context.GradeClearances.FirstOrDefaultAsync(gc => gc.UserID == student.UserID && gc.TermID == term.TermID);
        Assert.NotNull(clearance);
    }

    [Fact]
    public async Task GetProposedBlockAsync_PrerequisiteStatusAndMessages_PopulatedCorrectly()
    {
        var student = await CreateStudentAsync();
        _context.UserDetails.Add(new UserDetails
        {
            UserID = student.UserID,
            Firstname = "Test",
            Lastname = "Student",
            ProgramID = 1,
            YearLevel = 1
        });
        await _context.SaveChangesAsync();

        var term1 = await CreateTermAsync("2024-2025", 1);
        var currentTerm = await CreateTermAsync("2025-2026", 1);

        var prereqPassed = await CreateSubjectAsync("PREREQ1", "Passed Prereq");
        var prereqUnmet = await CreateSubjectAsync("PREREQ2", "Unmet Prereq");

        var subjectA = await CreateSubjectAsync("SUBJA", "Subject A");
        var subjectB = await CreateSubjectAsync("SUBJB", "Subject B");
        await AddPrerequisiteAsync(subjectA.SubjectID, prereqPassed.SubjectID);
        await AddPrerequisiteAsync(subjectB.SubjectID, prereqUnmet.SubjectID);

        // Prereq 1 was passed by student
        var prereqPassedClass = await CreateClassAsync(prereqPassed, term1, "PREREQ1-Sec");
        await SeedGradeAsync(student.UserID, prereqPassedClass, remarks: 1, loadStatus: 1);

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, currentTerm.TermID);

        var blockItemA = block.FirstOrDefault(b => b.SubjectId == subjectA.SubjectID);
        Assert.NotNull(blockItemA);
        Assert.Equal("met", blockItemA.PrerequisiteStatus);
        Assert.Empty(blockItemA.PrerequisiteMessages);

        var blockItemB = block.FirstOrDefault(b => b.SubjectId == subjectB.SubjectID);
        Assert.NotNull(blockItemB);
        Assert.Equal("unmet", blockItemB.PrerequisiteStatus);
        Assert.Single(blockItemB.PrerequisiteMessages);
        Assert.Contains("Prerequisite not met: PREREQ2", blockItemB.PrerequisiteMessages[0]);
    }

    // ── Part A: Proposed Block Flags ──────────────────────────────────────────

    [Fact]
    public async Task GetProposedBlockAsync_AlreadyPassed_FlagIsTrue()
    {
        var student = await CreateStudentAsync();
        _context.UserDetails.Add(new UserDetails
        {
            UserID = student.UserID,
            Firstname = "Test",
            Lastname = "Student",
            ProgramID = 1,
            YearLevel = 1
        });
        await _context.SaveChangesAsync();

        var term1 = await CreateTermAsync("2024-2025", 1);
        var currentTerm = await CreateTermAsync("2025-2026", 1);

        var subject = await CreateSubjectAsync("SUBJ1", "Subject One");
        var class1 = await CreateClassAsync(subject, term1, "SUBJ1-OldSec");
        await CreateClassAsync(subject, currentTerm, "SUBJ1-NewSec");

        // Student already passed the subject in a prior term
        await SeedGradeAsync(student.UserID, class1, remarks: 1, loadStatus: 1);

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, currentTerm.TermID);
        var item = block.FirstOrDefault(b => b.SubjectId == subject.SubjectID);

        Assert.NotNull(item);
        Assert.True(item.AlreadyPassed);
        Assert.False(item.AlreadyEnrolledThisTerm);
    }

    [Fact]
    public async Task GetProposedBlockAsync_AlreadyEnrolledThisTerm_FlagIsTrue()
    {
        var student = await CreateStudentAsync();
        _context.UserDetails.Add(new UserDetails
        {
            UserID = student.UserID,
            Firstname = "Test",
            Lastname = "Student",
            ProgramID = 1,
            YearLevel = 1
        });
        await _context.SaveChangesAsync();

        var currentTerm = await CreateTermAsync("2025-2026", 1);
        var subject = await CreateSubjectAsync("SUBJ2", "Subject Two");
        var sectionA = await CreateClassAsync(subject, currentTerm, "SUBJ2-SecA");
        await CreateClassAsync(subject, currentTerm, "SUBJ2-SecB");

        // Student has an Enrolled load for section A this term
        await SeedStudyLoadAsync(student.UserID, sectionA, StudyLoadStatus.Enrolled);

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, currentTerm.TermID);
        var item = block.FirstOrDefault(b => b.SubjectId == subject.SubjectID);

        Assert.NotNull(item);
        Assert.True(item.AlreadyEnrolledThisTerm);
    }

    [Fact]
    public async Task GetProposedBlockAsync_PendingLoadThisTerm_AlreadyEnrolledThisTerm_IsTrue()
    {
        var student = await CreateStudentAsync();
        _context.UserDetails.Add(new UserDetails
        {
            UserID = student.UserID,
            Firstname = "Test",
            Lastname = "Student",
            ProgramID = 1,
            YearLevel = 1
        });
        await _context.SaveChangesAsync();

        var currentTerm = await CreateTermAsync("2025-2026", 1);
        var subject = await CreateSubjectAsync("SUBJ3", "Subject Three");
        var section = await CreateClassAsync(subject, currentTerm, "SUBJ3-Sec");

        // Student has a Pending load this term
        await SeedStudyLoadAsync(student.UserID, section, StudyLoadStatus.Pending);

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, currentTerm.TermID);
        var item = block.FirstOrDefault(b => b.SubjectId == subject.SubjectID);

        Assert.NotNull(item);
        Assert.True(item.AlreadyEnrolledThisTerm);
    }

    [Fact]
    public async Task GetProposedBlockAsync_NoPriorHistory_BothFlagsFalse()
    {
        var student = await CreateStudentAsync();
        _context.UserDetails.Add(new UserDetails
        {
            UserID = student.UserID,
            Firstname = "Test",
            Lastname = "Student",
            ProgramID = 1,
            YearLevel = 1
        });
        await _context.SaveChangesAsync();

        var currentTerm = await CreateTermAsync("2025-2026", 1);
        var subject = await CreateSubjectAsync("SUBJ4", "Subject Four");
        await CreateClassAsync(subject, currentTerm, "SUBJ4-Sec");

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, currentTerm.TermID);
        var item = block.FirstOrDefault(b => b.SubjectId == subject.SubjectID);

        Assert.NotNull(item);
        Assert.False(item.AlreadyPassed);
        Assert.False(item.AlreadyEnrolledThisTerm);
    }

    [Fact]
    public async Task GetProposedBlockAsync_DroppedLoadThisTerm_AlreadyEnrolledThisTerm_IsFalse()
    {
        var student = await CreateStudentAsync();
        _context.UserDetails.Add(new UserDetails
        {
            UserID = student.UserID,
            Firstname = "Test",
            Lastname = "Student",
            ProgramID = 1,
            YearLevel = 1
        });
        await _context.SaveChangesAsync();

        var currentTerm = await CreateTermAsync("2025-2026", 1);
        var subject = await CreateSubjectAsync("SUBJ5", "Subject Five");
        var section = await CreateClassAsync(subject, currentTerm, "SUBJ5-Sec");

        // Student has a Dropped load (not active)
        await SeedStudyLoadAsync(student.UserID, section, StudyLoadStatus.Dropped);

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, currentTerm.TermID);
        var item = block.FirstOrDefault(b => b.SubjectId == subject.SubjectID);

        Assert.NotNull(item);
        Assert.False(item.AlreadyEnrolledThisTerm);
    }

    // ── Part B: Force Enrollment Audit ────────────────────────────────────────

    [Fact]
    public async Task EnrollSingleAsync_ForceTrue_MissingReason_ReturnsSuccessFalseWithWarning()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var term2 = await CreateTermAsync("2025-2026", 2);

        var prereqSubject = await CreateSubjectAsync("AUDIT_P1", "Audit Prereq 1");
        var targetSubject = await CreateSubjectAsync("AUDIT_T1", "Audit Target 1");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var prereqClass = await CreateClassAsync(prereqSubject, term1, "AUDIT_P1-Sec");
        var targetClass = await CreateClassAsync(targetSubject, term2, "AUDIT_T1-Sec");

        await SeedGradeAsync(student.UserID, prereqClass, remarks: 2);

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = true,
            ForceReason = null // missing reason
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);
        Assert.False(result.Success);
        Assert.Null(result.StudyLoadId);
        Assert.Contains("ForceReason is required", result.Warnings[0]);
    }

    [Fact]
    public async Task EnrollSingleAsync_ForceTrue_BlankReason_ReturnsSuccessFalseWithWarning()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var term2 = await CreateTermAsync("2025-2026", 2);

        var prereqSubject = await CreateSubjectAsync("AUDIT_P2", "Audit Prereq 2");
        var targetSubject = await CreateSubjectAsync("AUDIT_T2", "Audit Target 2");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var prereqClass = await CreateClassAsync(prereqSubject, term1, "AUDIT_P2-Sec");
        var targetClass = await CreateClassAsync(targetSubject, term2, "AUDIT_T2-Sec");

        await SeedGradeAsync(student.UserID, prereqClass, remarks: 2);

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = true,
            ForceReason = "   " // blank after trim
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);
        Assert.False(result.Success);
        Assert.Null(result.StudyLoadId);
        Assert.Contains("ForceReason is required", result.Warnings[0]);
    }

    [Fact]
    public async Task EnrollSingleAsync_ForceTrue_ReasonTooLong_ReturnsSuccessFalseWithWarning()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var term2 = await CreateTermAsync("2025-2026", 2);

        var prereqSubject = await CreateSubjectAsync("AUDIT_P3", "Audit Prereq 3");
        var targetSubject = await CreateSubjectAsync("AUDIT_T3", "Audit Target 3");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var prereqClass = await CreateClassAsync(prereqSubject, term1, "AUDIT_P3-Sec");
        var targetClass = await CreateClassAsync(targetSubject, term2, "AUDIT_T3-Sec");

        await SeedGradeAsync(student.UserID, prereqClass, remarks: 2);

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = true,
            ForceReason = new string('X', Api.Constants.ValidationConstants.NotesMax + 1)
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);
        Assert.False(result.Success);
        Assert.Null(result.StudyLoadId);
        Assert.Contains("must not exceed", result.Warnings[0]);
    }

    [Fact]
    public async Task EnrollSingleAsync_ForceTrue_WithReason_SetsAllThreeAuditColumns()
    {
        var student = await CreateStudentAsync();
        var term1 = await CreateTermAsync("2025-2026", 1);
        var term2 = await CreateTermAsync("2025-2026", 2);

        var prereqSubject = await CreateSubjectAsync("AUDIT_P4", "Audit Prereq 4");
        var targetSubject = await CreateSubjectAsync("AUDIT_T4", "Audit Target 4");
        await AddPrerequisiteAsync(targetSubject.SubjectID, prereqSubject.SubjectID);

        var prereqClass = await CreateClassAsync(prereqSubject, term1, "AUDIT_P4-Sec");
        var targetClass = await CreateClassAsync(targetSubject, term2, "AUDIT_T4-Sec");

        await SeedGradeAsync(student.UserID, prereqClass, remarks: 2);

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = targetClass.ClassID,
            Force = true,
            ForceReason = "  Per dean's request  "
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);
        Assert.True(result.Success);

        var load = await _context.StudyLoads.FindAsync(result.StudyLoadId);
        Assert.NotNull(load);
        Assert.True(load.IsForced);
        Assert.Equal(_registrarId, load.ForcedByUserID);
        Assert.Equal("Per dean's request", load.ForcedReason);
    }

    [Fact]
    public async Task GetByStudentAsync_StudentCaller_MasksForcedReasonAndUser()
    {
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);
        var subject = await CreateSubjectAsync("AUDIT_MASK", "Mask Subject");
        var cls = await CreateClassAsync(subject, term, "AUDIT_MASK-Sec");

        var load = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = cls.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow,
            IsForced = true,
            ForcedByUserID = _registrarId,
            ForcedReason = "Administrative override"
        };
        _context.StudyLoads.Add(load);
        await _context.SaveChangesAsync();

        // Student caller (isStudentCaller = true)
        var studentDtos = await _studyLoadService.GetByStudentAsync(student.UserID, term.TermID, isStudentCaller: true);
        Assert.Single(studentDtos);
        Assert.True(studentDtos[0].IsForced);
        Assert.Null(studentDtos[0].ForcedByUserID);
        Assert.Null(studentDtos[0].ForcedReason);

        // Staff caller (isStudentCaller = false)
        var staffDtos = await _studyLoadService.GetByStudentAsync(student.UserID, term.TermID, isStudentCaller: false);
        Assert.Single(staffDtos);
        Assert.True(staffDtos[0].IsForced);
        Assert.Equal(_registrarId, staffDtos[0].ForcedByUserID);
        Assert.Equal("Administrative override", staffDtos[0].ForcedReason);
    }

    [Fact]
    public async Task EnrollSingleAsync_ForceTrue_NoWarnings_IsNotForced()
    {
        // When Force=true but there are no validation findings, IsForced is false
        // and ForceReason is not required.
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);

        var subject = await CreateSubjectAsync("AUDIT_NW", "No Warnings Subject");
        var cls = await CreateClassAsync(subject, term, "AUDIT_NW-Sec");

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = cls.ClassID,
            Force = true,
            ForceReason = null // not required since there are no warnings
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);
        Assert.True(result.Success);
        Assert.NotNull(result.StudyLoadId);

        var load = await _context.StudyLoads.FindAsync(result.StudyLoadId);
        Assert.NotNull(load);
        Assert.False(load.IsForced);
        Assert.Null(load.ForcedByUserID);
        Assert.Null(load.ForcedReason);
    }

    [Fact]
    public async Task EnrollSingleAsync_NormalEnrollment_IsNotForced()
    {
        // Normal enrollment without Force=true should not set any force audit fields
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);

        var subject = await CreateSubjectAsync("AUDIT_NORM", "Normal Subject");
        var cls = await CreateClassAsync(subject, term, "AUDIT_NORM-Sec");

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = cls.ClassID,
            Force = false
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);
        Assert.True(result.Success);

        var load = await _context.StudyLoads.FindAsync(result.StudyLoadId);
        Assert.NotNull(load);
        Assert.False(load.IsForced);
        Assert.Null(load.ForcedByUserID);
        Assert.Null(load.ForcedReason);
    }

    [Fact]
    public async Task EnrollBatchAsync_NeverSetsIsForced()
    {
        // Batch path never sets IsForced, even for successful enrollments
        var student = await CreateStudentAsync();
        var term = await CreateTermAsync("2025-2026", 1);

        var subject = await CreateSubjectAsync("BATCH_NF", "Batch Subject");
        var cls = await CreateClassAsync(subject, term, "BATCH_NF-Sec");

        var dto = new EnrollBatchRequestDto
        {
            UserId = student.UserID,
            TermId = term.TermID,
            ClassIds = [cls.ClassID]
        };

        var results = await _studyLoadService.EnrollBatchAsync(dto, _registrarId);
        Assert.Single(results);
        Assert.True(results[0].Enrolled);

        var load = await _context.StudyLoads.FindAsync(results[0].StudyLoadId);
        Assert.NotNull(load);
        Assert.False(load.IsForced);
        Assert.Null(load.ForcedByUserID);
        Assert.Null(load.ForcedReason);
    }
}
