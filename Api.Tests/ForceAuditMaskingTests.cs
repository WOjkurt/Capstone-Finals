using Api.Auth;
using Api.Controllers;
using Api.Data;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
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

public class ForceAuditMaskingTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly Mock<IProgramScopingService> _scopingMock;
    private readonly Mock<IGradeClearanceService> _clearanceMock;
    private readonly StudyLoadRepository _studyLoadRepo;
    private readonly ClassRepository _classRepo;
    private readonly UserDetailsRepository _userDetailsRepo;
    private readonly StudyLoadService _studyLoadService;
    private readonly StudyLoadsController _studyLoadsController;

    private readonly AcademicTerm _term;
    private readonly AcademicProgram _program;
    private readonly Subject _subject;
    private readonly Class _class;
    private readonly User _teacher;
    private readonly User _student;
    private readonly User _registrar;
    private readonly StudyLoad _forcedLoad;
    private const string ForcedReasonText = "Prerequisite override approved by Dean";

    public ForceAuditMaskingTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _studyLoadRepo = new StudyLoadRepository(_context);
        _classRepo = new ClassRepository(_context);
        _userDetailsRepo = new UserDetailsRepository(_context);

        _scopingMock = new Mock<IProgramScopingService>();
        _clearanceMock = new Mock<IGradeClearanceService>();

        _studyLoadService = new StudyLoadService(
            _context,
            _studyLoadRepo,
            _clearanceMock.Object,
            NullLogger<StudyLoadService>.Instance);

        _studyLoadsController = new StudyLoadsController(
            _studyLoadService,
            _classRepo,
            _userDetailsRepo,
            _scopingMock.Object);

        // Seed basic academic structure
        _program = new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "Information Technology" };
        _context.AcademicPrograms.Add(_program);

        _term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 1, IsActive = true };
        _context.AcademicTerms.Add(_term);

        _subject = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = "IT301",
            SubjectTitle = "Database Systems",
            ProgramID = _program.ProgramID,
            LecUnits = 3,
            LabUnits = 0
        };
        _context.Subjects.Add(_subject);

        _teacher = new User
        {
            UserID = Guid.NewGuid(),
            Email = "teacher@dbtc-cebu.edu.ph",
            FirebaseUID = $"fb-{Guid.NewGuid():N}",
            Role = RoleUtils.Teacher,
            IsActive = true
        };
        _context.Users.Add(_teacher);

        _student = new User
        {
            UserID = Guid.NewGuid(),
            Email = "student@dbtc-cebu.edu.ph",
            FirebaseUID = $"fb-{Guid.NewGuid():N}",
            Role = RoleUtils.Student,
            IsActive = true
        };
        _context.Users.Add(_student);

        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = _student.UserID,
            Firstname = "Juan",
            Lastname = "Dela Cruz",
            ProgramID = _program.ProgramID
        });

        _registrar = new User
        {
            UserID = Guid.NewGuid(),
            Email = "registrar@dbtc-cebu.edu.ph",
            FirebaseUID = $"fb-{Guid.NewGuid():N}",
            Role = RoleUtils.Registrar,
            IsActive = true
        };
        _context.Users.Add(_registrar);

        _class = new Class
        {
            ClassID = Guid.NewGuid(),
            ClassName = "IT301-A",
            TermID = _term.TermID,
            SubjectID = _subject.SubjectID,
            UserID = _teacher.UserID,
            Subject = _subject,
            Term = _term
        };
        _context.Classes.Add(_class);

        // Create a forced study load with audit details populated
        _forcedLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = _student.UserID,
            ClassID = _class.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow,
            IsForced = true,
            ForcedByUserID = _registrar.UserID,
            ForcedReason = ForcedReasonText
        };
        _context.StudyLoads.Add(_forcedLoad);

        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void SetControllerContext(int role, Guid userId)
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Items["role"] = role;
        httpContext.Items["user_id"] = userId;
        _studyLoadsController.ControllerContext = new ControllerContext { HttpContext = httpContext };
    }

    // ── By-Class Endpoint Tests ─────────────────────────────────────────

    [Fact]
    public async Task GetByClass_TeacherCaller_MasksAllThreeAuditFields()
    {
        // Arrange: Teacher assigned to the class calling GET /api/studyloads/class/{classId}
        SetControllerContext(RoleUtils.Teacher, _teacher.UserID);

        // Act
        var result = await _studyLoadsController.GetByClass(_class.ClassID);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var loads = Assert.IsAssignableFrom<List<StudyLoadResponseDto>>(ok.Value);
        Assert.Single(loads);

        var dto = loads[0];
        Assert.Null(dto.IsForced);
        Assert.Null(dto.ForcedByUserID);
        Assert.Null(dto.ForcedReason);
    }

    [Theory]
    [InlineData(RoleUtils.Registrar)]
    [InlineData(RoleUtils.Admin)]
    [InlineData(RoleUtils.ProgramHead)]
    [InlineData(RoleUtils.CollegeHead)] // Note: College Head is allowed on purpose to view force enrollment audit info.
    public async Task GetByClass_AuthorizedRoles_SeeRealValues(int role)
    {
        // Arrange
        var callerUser = new User
        {
            UserID = Guid.NewGuid(),
            Email = $"caller_{role}@dbtc-cebu.edu.ph",
            FirebaseUID = $"fb-{Guid.NewGuid():N}",
            Role = role,
            IsActive = true
        };
        _context.Users.Add(callerUser);
        await _context.SaveChangesAsync();

        if (role == RoleUtils.ProgramHead)
        {
            _scopingMock.Setup(s => s.EnsureProgramHeadAccessAsync(callerUser.UserID, _program.ProgramID, "class"))
                .Returns(Task.CompletedTask);
        }

        SetControllerContext(role, callerUser.UserID);

        // Act
        var result = await _studyLoadsController.GetByClass(_class.ClassID);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var loads = Assert.IsAssignableFrom<List<StudyLoadResponseDto>>(ok.Value);
        Assert.Single(loads);

        var dto = loads[0];
        Assert.True(dto.IsForced);
        Assert.Equal(_registrar.UserID, dto.ForcedByUserID);
        Assert.Equal(ForcedReasonText, dto.ForcedReason);
    }

    // ── By-Student Endpoint Tests ───────────────────────────────────────

    [Fact]
    public async Task GetByStudent_StudentViewingSelf_MasksAllThreeAuditFields()
    {
        // Arrange: Student viewing own loads via GET /api/studyloads/student/{userId}
        SetControllerContext(RoleUtils.Student, _student.UserID);

        // Act
        var result = await _studyLoadsController.GetByStudent(_student.UserID, _term.TermID);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var loads = Assert.IsAssignableFrom<List<StudyLoadResponseDto>>(ok.Value);
        Assert.Single(loads);

        var dto = loads[0];
        Assert.Null(dto.IsForced);
        Assert.Null(dto.ForcedByUserID);
        Assert.Null(dto.ForcedReason);
    }

    [Theory]
    [InlineData(RoleUtils.Registrar)]
    [InlineData(RoleUtils.Admin)]
    [InlineData(RoleUtils.ProgramHead)]
    [InlineData(RoleUtils.CollegeHead)] // Note: College Head is allowed on purpose to view force enrollment audit info.
    public async Task GetByStudent_AuthorizedRoles_SeeRealValues(int role)
    {
        // Arrange
        var callerUser = new User
        {
            UserID = Guid.NewGuid(),
            Email = $"student_caller_{role}@dbtc-cebu.edu.ph",
            FirebaseUID = $"fb-{Guid.NewGuid():N}",
            Role = role,
            IsActive = true
        };
        _context.Users.Add(callerUser);
        await _context.SaveChangesAsync();

        if (role == RoleUtils.ProgramHead)
        {
            _scopingMock.Setup(s => s.EnsureProgramHeadAccessAsync(callerUser.UserID, _program.ProgramID, "student"))
                .Returns(Task.CompletedTask);
        }

        SetControllerContext(role, callerUser.UserID);

        // Act
        var result = await _studyLoadsController.GetByStudent(_student.UserID, _term.TermID);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var loads = Assert.IsAssignableFrom<List<StudyLoadResponseDto>>(ok.Value);
        Assert.Single(loads);

        var dto = loads[0];
        Assert.True(dto.IsForced);
        Assert.Equal(_registrar.UserID, dto.ForcedByUserID);
        Assert.Equal(ForcedReasonText, dto.ForcedReason);
    }

    // ── Helper Unit Tests ───────────────────────────────────────────────

    [Theory]
    [InlineData(RoleUtils.Registrar, true)]
    [InlineData(RoleUtils.Admin, true)]
    [InlineData(RoleUtils.ProgramHead, true)]
    [InlineData(RoleUtils.CollegeHead, true)] // Note: College Head is allowed on purpose
    [InlineData(RoleUtils.Teacher, false)]
    [InlineData(RoleUtils.Student, false)]
    [InlineData(null, false)]
    [InlineData(999, false)]
    public void CanViewForceAudit_RolePermissions_MatchSpecifications(int? role, bool expectedAllowed)
    {
        Assert.Equal(expectedAllowed, ForceAuditMaskingHelper.CanViewForceAudit(role));
    }

    [Fact]
    public void ApplyForceAuditMask_UnauthorizedRole_ClearsAuditFields()
    {
        var dto = new StudyLoadResponseDto
        {
            SubjectCode = "IT101",
            SubjectTitle = "Intro",
            ClassName = "Sec1",
            LoadStatus = "Enrolled",
            TermLabel = "2026 1st",
            IsForced = true,
            ForcedByUserID = Guid.NewGuid(),
            ForcedReason = "Test reason"
        };

        dto.ApplyForceAuditMask(RoleUtils.Teacher);

        Assert.Null(dto.IsForced);
        Assert.Null(dto.ForcedByUserID);
        Assert.Null(dto.ForcedReason);
    }

    [Fact]
    public void ApplyForceAuditMask_AuthorizedRole_PreservesAuditFields()
    {
        var expectedUserId = Guid.NewGuid();
        var dto = new StudyLoadResponseDto
        {
            SubjectCode = "IT101",
            SubjectTitle = "Intro",
            ClassName = "Sec1",
            LoadStatus = "Enrolled",
            TermLabel = "2026 1st",
            IsForced = true,
            ForcedByUserID = expectedUserId,
            ForcedReason = "Test reason"
        };

        // Note: College Head is allowed on purpose
        dto.ApplyForceAuditMask(RoleUtils.CollegeHead);

        Assert.True(dto.IsForced);
        Assert.Equal(expectedUserId, dto.ForcedByUserID);
        Assert.Equal("Test reason", dto.ForcedReason);
    }
}
