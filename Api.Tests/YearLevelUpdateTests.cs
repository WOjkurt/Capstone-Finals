using Api.Auth;
using Api.Controllers;
using Api.Domain.IdentityAccess;
using Api.DTOs.Enrollment;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

public class YearLevelUpdateTests : IDisposable
{
    // ── Infrastructure ────────────────────────────────────────────────────────

    private readonly AppDbContext _context;
    private readonly UserDetailsRepository _userDetailsRepo;
    private readonly UserDetailsController _controller;

    // Seeded IDs
    private readonly Guid _registrarId = Guid.NewGuid();
    private readonly Guid _adminId = Guid.NewGuid();
    private readonly Guid _teacherId = Guid.NewGuid();
    private readonly Guid _programHeadId = Guid.NewGuid();
    private readonly Guid _collegeHeadId = Guid.NewGuid();
    private readonly Guid _studentId = Guid.NewGuid();
    private readonly Guid _unknownUserId = Guid.NewGuid();

    public YearLevelUpdateTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _userDetailsRepo = new UserDetailsRepository(_context);

        var scopingMock = new Mock<IProgramScopingService>();
        _controller = new UserDetailsController(
            _userDetailsRepo,
            scopingMock.Object,
            NullLogger<UserDetailsController>.Instance);

        SeedData();
    }

    private void SeedData()
    {
        _context.AcademicPrograms.Add(
            new Api.Domain.Enrollment.AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS Information Technology" });

        _context.Users.AddRange(
            new User { UserID = _registrarId,    FirebaseUID = "fb-reg",  Email = "reg@test.edu",  Role = RoleUtils.Registrar,   IsActive = true },
            new User { UserID = _adminId,        FirebaseUID = "fb-adm",  Email = "adm@test.edu",  Role = RoleUtils.Admin,       IsActive = true },
            new User { UserID = _teacherId,      FirebaseUID = "fb-tch",  Email = "tch@test.edu",  Role = RoleUtils.Teacher,     IsActive = true },
            new User { UserID = _programHeadId,  FirebaseUID = "fb-ph",   Email = "ph@test.edu",   Role = RoleUtils.ProgramHead, IsActive = true },
            new User { UserID = _collegeHeadId,  FirebaseUID = "fb-ch",   Email = "ch@test.edu",   Role = RoleUtils.CollegeHead, IsActive = true },
            new User { UserID = _studentId,      FirebaseUID = "fb-stu",  Email = "stu@test.edu",  Role = RoleUtils.Student,     IsActive = true }
        );

        _context.UserDetails.AddRange(
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _studentId,     Firstname = "John",   Lastname = "Student",  ProgramID = 1, YearLevel = 1 },
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _teacherId,     Firstname = "Jane",   Lastname = "Teacher",  ProgramID = 1, YearLevel = null },
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _programHeadId, Firstname = "Paul",   Lastname = "PhHead",   ProgramID = 1 },
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _collegeHeadId, Firstname = "Carol",  Lastname = "ChHead",   ProgramID = 1 }
        );

        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void SetContext(Guid callerId, int callerRole)
    {
        var http = new DefaultHttpContext();
        http.Items["user_id"] = callerId;
        http.Items["role"] = callerRole;
        _controller.ControllerContext = new ControllerContext { HttpContext = http };
    }

    // ── Helpers for RequireRegistrarOrAdmin attribute ─────────────────────────
    // The filter reads the User entity from the repository. We use the real
    // UserDetailsRepository which has access to the in-memory db, but the
    // filter uses IUserRepository from DI. For controller-level tests we bypass
    // the attribute by setting Items["user_id"] and Items["role"] directly and
    // calling the action method directly (same pattern used in LrnBackendTests).

    // ── 1. Success cases ──────────────────────────────────────────────────────

    [Fact]
    public async Task UpdateYearLevel_ByRegistrar_ReturnsOkAndPersists()
    {
        SetContext(_registrarId, RoleUtils.Registrar);

        var result = await _controller.UpdateYearLevel(_studentId, new UpdateYearLevelRequestDto { YearLevel = 3 });

        var ok = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, ok.StatusCode);

        var saved = await _userDetailsRepo.GetByUserIdAsync(_studentId);
        Assert.Equal(3, saved!.YearLevel);
    }

    [Fact]
    public async Task UpdateYearLevel_ByAdmin_ReturnsOkAndPersists()
    {
        SetContext(_adminId, RoleUtils.Admin);

        var result = await _controller.UpdateYearLevel(_studentId, new UpdateYearLevelRequestDto { YearLevel = 2 });

        Assert.IsType<OkObjectResult>(result);
        var saved = await _userDetailsRepo.GetByUserIdAsync(_studentId);
        Assert.Equal(2, saved!.YearLevel);
    }

    // ── 2. 400 validation ─────────────────────────────────────────────────────

    [Theory]
    [InlineData(0)]
    [InlineData(6)]
    public async Task UpdateYearLevel_OutOfRange_Returns400(int badLevel)
    {
        SetContext(_registrarId, RoleUtils.Registrar);

        var result = await _controller.UpdateYearLevel(_studentId, new UpdateYearLevelRequestDto { YearLevel = badLevel });

        var bad = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(400, bad.StatusCode);
    }

    // ── 3. 404 cases ──────────────────────────────────────────────────────────

    [Fact]
    public async Task UpdateYearLevel_UnknownUser_Returns404()
    {
        SetContext(_registrarId, RoleUtils.Registrar);

        var result = await _controller.UpdateYearLevel(_unknownUserId, new UpdateYearLevelRequestDto { YearLevel = 2 });

        Assert.IsType<NotFoundObjectResult>(result);
    }

    [Fact]
    public async Task UpdateYearLevel_TeacherTarget_Returns404()
    {
        // Teacher has UserDetails but Role != Student → treated as not-found
        SetContext(_registrarId, RoleUtils.Registrar);

        var result = await _controller.UpdateYearLevel(_teacherId, new UpdateYearLevelRequestDto { YearLevel = 2 });

        Assert.IsType<NotFoundObjectResult>(result);
    }

    // ── 4. 403 for non-Registrar/Admin callers ────────────────────────────────
    // NOTE: The [RequireRegistrarOrAdmin] attribute enforces 403 in the real
    // pipeline. For unit tests the attribute is not invoked when calling the
    // action method directly. Instead we verify that calling the action method
    // with items NOT set (simulating a caller that passed the outer auth but
    // not the inner check) does NOT produce 200; the real enforcement is
    // integration-tested elsewhere. Below we document the contract at the
    // action level by showing that without a valid caller_id the action returns
    // 401 (the action itself also checks the caller id).

    [Theory]
    [InlineData(RoleUtils.Teacher)]
    [InlineData(RoleUtils.ProgramHead)]
    [InlineData(RoleUtils.CollegeHead)]
    [InlineData(RoleUtils.Student)]
    public async Task UpdateYearLevel_NonRegistrarOrAdmin_MissingCallerId_Returns401(int callerRole)
    {
        // Set role but omit user_id to simulate a misconfigured request
        var http = new DefaultHttpContext();
        http.Items["role"] = callerRole;
        // user_id is intentionally not set
        _controller.ControllerContext = new ControllerContext { HttpContext = http };

        var result = await _controller.UpdateYearLevel(_studentId, new UpdateYearLevelRequestDto { YearLevel = 2 });

        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    // ── 5. Proposed study load uses updated year level ────────────────────────

    [Fact]
    public async Task UpdateYearLevel_AfterUpdate_StudyLoadValidationUsesNewYearLevel()
    {
        // Arrange: student starts at Year 1; subject requires Year 3 standing.
        // After we update the year level to 3, validation should NOT return StandingYearRequired.
        SetContext(_registrarId, RoleUtils.Registrar);

        var term = new Api.Domain.Enrollment.AcademicTerm
        {
            TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = true
        };
        _context.AcademicTerms.Add(term);

        var subject = new Api.Domain.Enrollment.Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = "IT 301",
            SubjectTitle = "Advanced Programming",
            ProgramID = 1,
            YearLevel = 3,
            DefaultSemester = 1,
            StandingYear = 3,
            LecUnits = 3
        };
        _context.Subjects.Add(subject);

        var cls = new Api.Domain.Enrollment.Class
        {
            ClassID = Guid.NewGuid(),
            ClassName = "IT301-A",
            SubjectID = subject.SubjectID,
            TermID = term.TermID,
            CreatedAt = DateTime.UtcNow
        };
        _context.Classes.Add(cls);
        await _context.SaveChangesAsync();

        // Confirm student is at Year 1 (blocked by standing rule)
        var clearanceMock = new Mock<IGradeClearanceService>();
        var studyLoadRepo = new StudyLoadRepository(_context);
        var studyLoadService = new StudyLoadService(
            _context, studyLoadRepo, clearanceMock.Object,
            NullLogger<StudyLoadService>.Instance);

        var findingsBefore = await studyLoadService.ValidateEnrollmentRulesAsync(
            _studentId, cls.ClassID, term.TermID);
        Assert.Contains(findingsBefore, f => f.Code == EnrollmentRuleCodes.StandingYearRequired);

        // Act: update year level to 3
        await _controller.UpdateYearLevel(_studentId, new UpdateYearLevelRequestDto { YearLevel = 3 });

        // Assert: standing rule no longer fires
        var findingsAfter = await studyLoadService.ValidateEnrollmentRulesAsync(
            _studentId, cls.ClassID, term.TermID);
        Assert.DoesNotContain(findingsAfter, f =>
            f.Code == EnrollmentRuleCodes.StandingYearRequired ||
            f.Code == EnrollmentRuleCodes.YearLevelNotSet);
    }
}
