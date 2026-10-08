using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Integration-style tests (real in-memory DB, real repositories, real services)
/// verifying that GradeClearance records are auto-created during enrollment and
/// that the idempotency and no-op guarantees hold.
/// </summary>
public class StudyLoadServiceClearanceTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly StudyLoadRepository _studyLoadRepo;
    private readonly GradeClearanceRepository _clearanceRepo;
    private readonly GradeClearanceService _clearanceService;
    private readonly StudyLoadService _studyLoadService;

    // IDs shared across helpers
    private readonly Guid _registrarId = Guid.NewGuid();

    public StudyLoadServiceClearanceTests()
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

    // ── Helpers ───────────────────────────────────────────────────────────────

    /// <summary>Seeds a User + AcademicTerm + Class (with Subject) and returns their IDs.</summary>
    private async Task<(Guid userId, Guid termId, Guid classId)> SeedStudentTermClassAsync()
    {
        var userId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        var subjectId = Guid.NewGuid();
        var classId = Guid.NewGuid();

        _context.Users.Add(new User
        {
            UserID = userId,
            FirebaseUID = "fb-" + Guid.NewGuid(),
            Email = "student@dbtc-cebu.edu.ph",
            Role = 5,
            IsActive = true
        });

        _context.AcademicTerms.Add(new AcademicTerm
        {
            TermID = termId,
            SchoolYear = "2025-2026",
            Semester = 1,
            IsActive = true
        });

        _context.Subjects.Add(new Subject
        {
            SubjectID = subjectId,
            SubjectCode = "IT101",
            SubjectTitle = "Intro to IT",
            ProgramID = 1
        });

        _context.Classes.Add(new Class
        {
            ClassID = classId,
            ClassName = "BSIT 1A",
            SubjectID = subjectId,
            TermID = termId,
            CreatedAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync();
        return (userId, termId, classId);
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    /// <summary>
    /// EnrollBatchAsync with a single class creates exactly one GradeClearance
    /// for the (UserId, TermId) pair.
    /// </summary>
    [Fact]
    public async Task EnrollBatchAsync_SingleClass_CreatesOneGradeClearance()
    {
        // Arrange
        var (userId, termId, classId) = await SeedStudentTermClassAsync();

        var dto = new EnrollBatchRequestDto
        {
            UserId = userId,
            TermId = termId,
            ClassIds = [classId]
        };

        // Act
        await _studyLoadService.EnrollBatchAsync(dto, _registrarId);

        // Assert
        var clearances = await _context.GradeClearances
            .Where(gc => gc.UserID == userId && gc.TermID == termId)
            .ToListAsync();

        Assert.Single(clearances);
        Assert.False(clearances[0].IsCleared); // defaults to Hold/Uncleared
    }

    /// <summary>
    /// EnrollBatchAsync enrolling a student into TWO classes within the SAME term
    /// must create exactly ONE GradeClearance record, not one per class.
    /// This verifies the idempotency design of EnsureClearanceAsync.
    /// </summary>
    [Fact]
    public async Task EnrollBatchAsync_MultipleClassesSameTerm_CreatesExactlyOneGradeClearance()
    {
        // Arrange — seed two classes in the same term
        var (userId, termId, classId1) = await SeedStudentTermClassAsync();

        // Second class, same term
        var subjectId2 = Guid.NewGuid();
        var classId2 = Guid.NewGuid();
        _context.Subjects.Add(new Subject
        {
            SubjectID = subjectId2,
            SubjectCode = "IT102",
            SubjectTitle = "Programming Fundamentals",
            ProgramID = 1
        });
        _context.Classes.Add(new Class
        {
            ClassID = classId2,
            ClassName = "BSIT 1B",
            SubjectID = subjectId2,
            TermID = termId,
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        var dto = new EnrollBatchRequestDto
        {
            UserId = userId,
            TermId = termId,
            ClassIds = [classId1, classId2]
        };

        // Act
        await _studyLoadService.EnrollBatchAsync(dto, _registrarId);

        // Assert — must be exactly ONE clearance record for this student + term
        var clearanceCount = await _context.GradeClearances
            .CountAsync(gc => gc.UserID == userId && gc.TermID == termId);

        Assert.Equal(1, clearanceCount);
    }

    /// <summary>
    /// EnrollBatchAsync with an empty ClassIds list (nothing to enroll, so
    /// resultList.Count == 0) must NOT create any GradeClearance record.
    /// Verifies the guard: if (resultList.Count > 0).
    /// </summary>
    [Fact]
    public async Task EnrollBatchAsync_NothingEnrolled_DoesNotCreateGradeClearance()
    {
        // Arrange — an empty class list means no StudyLoads are created,
        // resultList remains empty, and EnsureClearanceAsync is never called.
        var (userId, termId, _) = await SeedStudentTermClassAsync();

        var dto = new EnrollBatchRequestDto
        {
            UserId = userId,
            TermId = termId,
            ClassIds = [] // empty — nothing will be enrolled
        };

        // Act
        await _studyLoadService.EnrollBatchAsync(dto, _registrarId);

        // Assert — no clearance record should have been created
        var clearanceCount = await _context.GradeClearances
            .CountAsync(gc => gc.UserID == userId && gc.TermID == termId);

        Assert.Equal(0, clearanceCount);
    }

    /// <summary>
    /// EnrollSingleAsync creates exactly one GradeClearance for the
    /// (UserId, TermId) pair when the enrollment succeeds.
    /// </summary>
    [Fact]
    public async Task EnrollSingleAsync_SuccessfulEnrollment_CreatesGradeClearance()
    {
        // Arrange
        var (userId, termId, classId) = await SeedStudentTermClassAsync();

        var dto = new EnrollSingleRequestDto
        {
            UserId = userId,
            ClassId = classId,
            Force = false
        };

        // Act
        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId);

        // Assert — enrollment succeeded and clearance was created
        Assert.True(result.Success);

        var clearances = await _context.GradeClearances
            .Where(gc => gc.UserID == userId && gc.TermID == termId)
            .ToListAsync();

        Assert.Single(clearances);
        Assert.False(clearances[0].IsCleared); // defaults to Hold/Uncleared
    }

    /// <summary>
    /// Calling EnrollBatchAsync a second time for the same student + term
    /// (e.g. adding another class later) must still leave exactly ONE
    /// GradeClearance record — EnsureClearanceAsync is idempotent.
    /// </summary>
    [Fact]
    public async Task EnrollBatchAsync_CalledTwiceForSameTerm_StillExactlyOneClearance()
    {
        // Arrange
        var (userId, termId, classId1) = await SeedStudentTermClassAsync();

        var subjectId2 = Guid.NewGuid();
        var classId2 = Guid.NewGuid();
        _context.Subjects.Add(new Subject
        {
            SubjectID = subjectId2,
            SubjectCode = "IT103",
            SubjectTitle = "Data Structures",
            ProgramID = 1
        });
        _context.Classes.Add(new Class
        {
            ClassID = classId2,
            ClassName = "BSIT 1C",
            SubjectID = subjectId2,
            TermID = termId,
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        // First batch
        await _studyLoadService.EnrollBatchAsync(new EnrollBatchRequestDto
        {
            UserId = userId,
            TermId = termId,
            ClassIds = [classId1]
        }, _registrarId);

        // Second batch — same term, different class
        await _studyLoadService.EnrollBatchAsync(new EnrollBatchRequestDto
        {
            UserId = userId,
            TermId = termId,
            ClassIds = [classId2]
        }, _registrarId);

        // Assert
        var clearanceCount = await _context.GradeClearances
            .CountAsync(gc => gc.UserID == userId && gc.TermID == termId);

        Assert.Equal(1, clearanceCount);
    }
}
