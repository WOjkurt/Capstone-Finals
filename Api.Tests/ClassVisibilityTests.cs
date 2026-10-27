using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Class;
using Api.DTOs.Setup;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

namespace Api.Tests;

// ─────────────────────────────────────────────────────────────────────────────
// Stage 5B – Class & Subject Visibility Tests
// Verifies GET /api/classes and GET /api/subjects access rules for every role.
// ─────────────────────────────────────────────────────────────────────────────

public class ClassVisibilityControllerTests
{
    private readonly Mock<IClassService> _classServiceMock = new();
    private readonly Mock<IClassScheduleService> _scheduleServiceMock = new();
    private readonly Mock<IClassRepository> _classRepoMock = new();
    private readonly Mock<ISubjectRepository> _subjectRepoMock = new();
    private readonly Mock<IProgramScopingService> _scopingServiceMock = new();
    private readonly Mock<IUserDetailsRepository> _userDetailsRepoMock = new();
    private readonly ClassesController _controller;

    public ClassVisibilityControllerTests()
    {
        _controller = new ClassesController(
            _classServiceMock.Object,
            _scheduleServiceMock.Object,
            _scopingServiceMock.Object,
            _classRepoMock.Object,
            _subjectRepoMock.Object,
            _userDetailsRepoMock.Object);
    }

    private void SetHttpContext(int role, Guid userId)
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Items["role"] = role;
        httpContext.Items["user_id"] = userId;
        _controller.ControllerContext = new ControllerContext { HttpContext = httpContext };
    }

    // ── Year-level filter ─────────────────────────────────────────────────────

    [Fact]
    public async Task GetAll_WithYearLevelFilter_ForwardsYearLevelToService()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);
        var classesYr2 = new List<ClassDto>
        {
            new() { ClassID = Guid.NewGuid(), ClassName = "BSIT-2A", SubjectID = Guid.NewGuid(), YearLevel = 2 }
        };
        _classServiceMock
            .Setup(s => s.GetAllAsync(null, null, null, null, null, 2))
            .ReturnsAsync(classesYr2);

        // Act
        var result = await _controller.GetAll(null, null, null, 2);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<IEnumerable<ClassDto>>(ok.Value);
        Assert.All(list, c => Assert.Equal(2, c.YearLevel));
        _classServiceMock.Verify(s => s.GetAllAsync(null, null, null, null, null, 2), Times.Once);
    }

    [Fact]
    public async Task GetAll_YearLevelNull_NoYearLevelFilterApplied()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);
        _classServiceMock
            .Setup(s => s.GetAllAsync(null, null, null, null, null, null))
            .ReturnsAsync(new List<ClassDto>());

        // Act
        var result = await _controller.GetAll(null, null, null, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _classServiceMock.Verify(s => s.GetAllAsync(null, null, null, null, null, null), Times.Once);
    }

    // ── ClassDto.YearLevel populated ──────────────────────────────────────────

    [Fact]
    public async Task GetAll_ReturnsClassDtoWithYearLevel_WhenServiceProvidesIt()
    {
        // Arrange
        var registrarId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Registrar, registrarId);
        var classes = new List<ClassDto>
        {
            new() { ClassID = Guid.NewGuid(), ClassName = "BSIT-1A", SubjectID = Guid.NewGuid(), YearLevel = 1 },
            new() { ClassID = Guid.NewGuid(), ClassName = "BSIT-3B", SubjectID = Guid.NewGuid(), YearLevel = 3 },
        };
        _classServiceMock
            .Setup(s => s.GetAllAsync(null, null, null, null, null, null))
            .ReturnsAsync(classes);

        // Act
        var result = await _controller.GetAll(null, null, null, null);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<IEnumerable<ClassDto>>(ok.Value).ToList();
        Assert.Equal(2, list.Count);
        Assert.Equal(1, list[0].YearLevel);
        Assert.Equal(3, list[1].YearLevel);
    }

    // ── Program Head: no program = empty list ─────────────────────────────────

    [Fact]
    public async Task GetAll_ProgramHeadWithoutAssignedProgram_ReturnsEmptyList()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);
        _scopingServiceMock.Setup(s => s.GetProgramIdAsync(programHeadId)).ReturnsAsync((int?)null);

        // Act
        var result = await _controller.GetAll(null, null, null, null);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<IEnumerable<ClassDto>>(ok.Value);
        Assert.Empty(list);
        _classServiceMock.Verify(
            s => s.GetAllAsync(It.IsAny<Guid?>(), It.IsAny<Guid?>(), It.IsAny<Guid?>(),
                               It.IsAny<int?>(), It.IsAny<Guid?>(), It.IsAny<int?>()),
            Times.Never);
    }

    // ── Admin: sees all, no scoping ───────────────────────────────────────────

    [Fact]
    public async Task GetAll_AdminRole_DoesNotScopeByProgram()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);
        _classServiceMock
            .Setup(s => s.GetAllAsync(null, null, null, null, null, null))
            .ReturnsAsync(new List<ClassDto>());

        // Act
        var result = await _controller.GetAll(null, null, null, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.GetProgramIdAsync(It.IsAny<Guid>()), Times.Never);
    }

    // ── Registrar: sees all, no scoping ──────────────────────────────────────

    [Fact]
    public async Task GetAll_RegistrarRole_DoesNotScopeByProgram()
    {
        // Arrange
        var registrarId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Registrar, registrarId);
        _classServiceMock
            .Setup(s => s.GetAllAsync(null, null, null, null, null, null))
            .ReturnsAsync(new List<ClassDto>());

        // Act
        var result = await _controller.GetAll(null, null, null, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.GetProgramIdAsync(It.IsAny<Guid>()), Times.Never);
    }

    // ── College Head: sees all, no scoping ───────────────────────────────────

    [Fact]
    public async Task GetAll_CollegeHeadRole_DoesNotScopeByProgram()
    {
        // Arrange
        var collegeHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.CollegeHead, collegeHeadId);
        _classServiceMock
            .Setup(s => s.GetAllAsync(null, null, null, null, null, null))
            .ReturnsAsync(new List<ClassDto>());

        // Act
        var result = await _controller.GetAll(null, null, null, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.GetProgramIdAsync(It.IsAny<Guid>()), Times.Never);
    }

    // ── Program Head: teacherUserId == self bypasses program scope ────────────

    [Fact]
    public async Task GetAll_ProgramHeadQueryingOwnClasses_BypassesProgramScope()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);
        _classServiceMock
            .Setup(s => s.GetAllAsync(null, null, programHeadId, null, null, null))
            .ReturnsAsync(new List<ClassDto>());

        // Act – teacherUserId == self
        var result = await _controller.GetAll(null, null, programHeadId, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.GetProgramIdAsync(It.IsAny<Guid>()), Times.Never);
    }

    // ── Program Head: another teacherUserId triggers program scoping ──────────

    [Fact]
    public async Task GetAll_ProgramHeadQueryingOtherTeacher_ScopesByProgram()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        var otherTeacherId = Guid.NewGuid();
        int programId = 3;
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);
        _scopingServiceMock.Setup(s => s.GetProgramIdAsync(programHeadId)).ReturnsAsync(programId);
        _classServiceMock
            .Setup(s => s.GetAllAsync(null, null, otherTeacherId, programId, null, null))
            .ReturnsAsync(new List<ClassDto>());

        // Act
        var result = await _controller.GetAll(null, null, otherTeacherId, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _classServiceMock.Verify(s => s.GetAllAsync(null, null, otherTeacherId, programId, null, null), Times.Once);
    }

    // ── Unauthenticated ───────────────────────────────────────────────────────

    [Fact]
    public async Task GetAll_NoAuthContext_Returns401()
    {
        // Arrange – empty HttpContext (no user_id)
        _controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() };

        // Act
        var result = await _controller.GetAll(null, null, null, null);

        // Assert
        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    // ── Teacher Role Scoping ──────────────────────────────────────────────────

    [Fact]
    public async Task GetAll_Teacher_ScopesToOwnClassesOnly()
    {
        // Arrange
        var teacherId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Teacher, teacherId);
        _classServiceMock
            .Setup(s => s.GetAllAsync(null, null, teacherId, null, null, null))
            .ReturnsAsync(new List<ClassDto>());

        // Act - teacher passes no teacherUserId
        var result = await _controller.GetAll(null, null, null, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _classServiceMock.Verify(s => s.GetAllAsync(null, null, teacherId, null, null, null), Times.Once);
    }

    [Fact]
    public async Task GetAll_TeacherQueryingOtherTeacher_Returns403()
    {
        // Arrange
        var teacherId = Guid.NewGuid();
        var otherTeacherId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Teacher, teacherId);

        // Act - teacher specifies another teacher's ID
        var result = await _controller.GetAll(null, null, otherTeacherId, null);

        // Assert
        Assert.IsType<ForbidResult>(result);
        _classServiceMock.Verify(s => s.GetAllAsync(It.IsAny<Guid?>(), It.IsAny<Guid?>(), It.IsAny<Guid?>(), It.IsAny<int?>(), It.IsAny<Guid?>(), It.IsAny<int?>()), Times.Never);
    }

    // ── Student Role Scoping ──────────────────────────────────────────────────

    [Fact]
    public async Task GetAll_Student_ScopesToCallerStudentId()
    {
        // Arrange
        var studentId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Student, studentId);
        _classServiceMock
            .Setup(s => s.GetAllAsync(null, null, null, null, studentId, null))
            .ReturnsAsync(new List<ClassDto>());

        // Act
        var result = await _controller.GetAll(null, null, null, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _classServiceMock.Verify(s => s.GetAllAsync(null, null, null, null, studentId, null), Times.Once);
    }

    [Fact]
    public async Task GetAll_UnknownRole_Returns403()
    {
        // Arrange
        SetHttpContext(99, Guid.NewGuid());

        // Act
        var result = await _controller.GetAll(null, null, null, null);

        // Assert
        Assert.IsType<ForbidResult>(result);
    }

    // ── GetById: Role-based Visibility ────────────────────────────────────────

    [Fact]
    public async Task GetById_Teacher_OwnClass_Returns200()
    {
        // Arrange
        var teacherId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Teacher, teacherId);
        _classServiceMock.Setup(s => s.GetByIdAsync(classId)).ReturnsAsync(new ClassDto { ClassID = classId, ClassName = "IT101" });
        _classServiceMock.Setup(s => s.CanAccessClassAsync(classId, teacherId, RoleUtils.Teacher)).ReturnsAsync(true);

        // Act
        var result = await _controller.GetById(classId);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var dto = Assert.IsType<ClassDto>(ok.Value);
        Assert.Equal(classId, dto.ClassID);
    }

    [Fact]
    public async Task GetById_Teacher_OtherClass_Returns403()
    {
        // Arrange
        var teacherId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Teacher, teacherId);
        _classServiceMock.Setup(s => s.GetByIdAsync(classId)).ReturnsAsync(new ClassDto { ClassID = classId, ClassName = "IT101" });
        _classServiceMock.Setup(s => s.CanAccessClassAsync(classId, teacherId, RoleUtils.Teacher)).ReturnsAsync(false);

        // Act
        var result = await _controller.GetById(classId);

        // Assert
        Assert.IsType<ForbidResult>(result);
    }

    [Fact]
    public async Task GetById_Student_EnrolledClass_Returns200()
    {
        // Arrange
        var studentId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Student, studentId);
        _classServiceMock.Setup(s => s.GetByIdAsync(classId)).ReturnsAsync(new ClassDto { ClassID = classId, ClassName = "IT101" });
        _classServiceMock.Setup(s => s.CanAccessClassAsync(classId, studentId, RoleUtils.Student)).ReturnsAsync(true);

        // Act
        var result = await _controller.GetById(classId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task GetById_Student_NotEnrolledClass_Returns403()
    {
        // Arrange
        var studentId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Student, studentId);
        _classServiceMock.Setup(s => s.GetByIdAsync(classId)).ReturnsAsync(new ClassDto { ClassID = classId, ClassName = "IT101" });
        _classServiceMock.Setup(s => s.CanAccessClassAsync(classId, studentId, RoleUtils.Student)).ReturnsAsync(false);

        // Act
        var result = await _controller.GetById(classId);

        // Assert
        Assert.IsType<ForbidResult>(result);
    }

    [Fact]
    public async Task GetById_ProgramHead_OwnProgram_Returns200()
    {
        // Arrange
        var phId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, phId);
        _classServiceMock.Setup(s => s.GetByIdAsync(classId)).ReturnsAsync(new ClassDto { ClassID = classId, ClassName = "IT101" });
        _classServiceMock.Setup(s => s.CanAccessClassAsync(classId, phId, RoleUtils.ProgramHead)).ReturnsAsync(true);

        // Act
        var result = await _controller.GetById(classId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task GetById_ProgramHead_OtherProgramNotTeaching_Returns403()
    {
        // Arrange
        var phId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, phId);
        _classServiceMock.Setup(s => s.GetByIdAsync(classId)).ReturnsAsync(new ClassDto { ClassID = classId, ClassName = "BA101" });
        _classServiceMock.Setup(s => s.CanAccessClassAsync(classId, phId, RoleUtils.ProgramHead)).ReturnsAsync(false);

        // Act
        var result = await _controller.GetById(classId);

        // Assert
        Assert.IsType<ForbidResult>(result);
    }

    [Fact]
    public async Task GetById_ProgramHead_ClassTheyTeach_Returns200()
    {
        // Arrange
        var phId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, phId);
        _classServiceMock.Setup(s => s.GetByIdAsync(classId)).ReturnsAsync(new ClassDto { ClassID = classId, ClassName = "GEN101", UserID = phId });
        _classServiceMock.Setup(s => s.CanAccessClassAsync(classId, phId, RoleUtils.ProgramHead)).ReturnsAsync(true);

        // Act
        var result = await _controller.GetById(classId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
    }

    [Theory]
    [InlineData(RoleUtils.Admin)]
    [InlineData(RoleUtils.Registrar)]
    [InlineData(RoleUtils.CollegeHead)]
    public async Task GetById_AdminRegistrarCollegeHead_CanAccessAnyClass(int role)
    {
        // Arrange
        var callerId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        SetHttpContext(role, callerId);
        _classServiceMock.Setup(s => s.GetByIdAsync(classId)).ReturnsAsync(new ClassDto { ClassID = classId, ClassName = "ANY101" });
        _classServiceMock.Setup(s => s.CanAccessClassAsync(classId, callerId, role)).ReturnsAsync(true);

        // Act
        var result = await _controller.GetById(classId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task GetById_UnknownClass_Returns404()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var classId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);
        _classServiceMock.Setup(s => s.GetByIdAsync(classId)).ReturnsAsync((ClassDto?)null);

        // Act
        var result = await _controller.GetById(classId);

        // Assert
        Assert.IsType<NotFoundObjectResult>(result);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject Visibility – uses real SubjectService + in-memory DB
// ─────────────────────────────────────────────────────────────────────────────

public class SubjectVisibilityTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly SubjectsController _controller;
    private readonly Mock<IProgramScopingService> _scopingMock = new();

    private readonly Guid _programHeadId = Guid.NewGuid();
    private readonly Guid _adminId = Guid.NewGuid();
    private readonly Guid _registrarId = Guid.NewGuid();

    // Two programs
    private const int Program1 = 1; // BSIT
    private const int Program2 = 2; // BSCS

    private Guid _subjectProgram1 = Guid.NewGuid();
    private Guid _subjectProgram2 = Guid.NewGuid();

    public SubjectVisibilityTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);

        SeedData();

        var subjectRepo = new SubjectRepository(_context);
        var prereqRepo = new SubjectPrerequisiteRepository(_context);
        var programRepo = new AcademicProgramRepository(_context);
        var subjectService = new SubjectService(_context, subjectRepo, prereqRepo, programRepo);

        _controller = new SubjectsController(subjectService, _scopingMock.Object);
    }

    private void SeedData()
    {
        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = Program1, ProgramCode = "BSIT", ProgramName = "BS Information Technology" },
            new AcademicProgram { ProgramID = Program2, ProgramCode = "BSCS", ProgramName = "BS Computer Science" }
        );
        _context.Subjects.AddRange(
            new Subject
            {
                SubjectID = _subjectProgram1,
                SubjectCode = "IT101",
                SubjectTitle = "Intro to IT",
                ProgramID = Program1,
                YearLevel = 1,
                DefaultSemester = 1
            },
            new Subject
            {
                SubjectID = _subjectProgram2,
                SubjectCode = "CS101",
                SubjectTitle = "Intro to CS",
                ProgramID = Program2,
                YearLevel = 1,
                DefaultSemester = 1
            }
        );
        _context.SaveChanges();
    }

    private void SetHttpContext(int role, Guid userId)
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Items["role"] = role;
        httpContext.Items["user_id"] = userId;
        _controller.ControllerContext = new ControllerContext { HttpContext = httpContext };
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    // ── GetAll: Program Head sees only own program ────────────────────────────

    [Fact]
    public async Task GetAll_ProgramHead_OnlySeesOwnProgramSubjects()
    {
        // Arrange
        SetHttpContext(RoleUtils.ProgramHead, _programHeadId);
        _scopingMock.Setup(s => s.GetProgramIdAsync(_programHeadId)).ReturnsAsync(Program1);

        // Act
        var result = await _controller.GetAll(null, null);

        // Assert – only IT101 returned, not CS101
        var ok = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<IEnumerable<SubjectDto>>(ok.Value).ToList();
        Assert.Single(list);
        Assert.Equal("IT101", list[0].SubjectCode);
    }

    [Fact]
    public async Task GetAll_ProgramHead_ClientSuppliedProgramIdIsIgnored()
    {
        // Arrange – client sends programId=2 (BSCS) but PH is Program 1
        SetHttpContext(RoleUtils.ProgramHead, _programHeadId);
        _scopingMock.Setup(s => s.GetProgramIdAsync(_programHeadId)).ReturnsAsync(Program1);

        // Act
        var result = await _controller.GetAll(Program2, null); // ignored

        // Assert – still only sees Program 1
        var ok = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<IEnumerable<SubjectDto>>(ok.Value).ToList();
        Assert.Single(list);
        Assert.Equal("IT101", list[0].SubjectCode);
    }

    [Fact]
    public async Task GetAll_ProgramHead_NoProgram_ReturnsEmptyList()
    {
        // Arrange
        SetHttpContext(RoleUtils.ProgramHead, _programHeadId);
        _scopingMock.Setup(s => s.GetProgramIdAsync(_programHeadId)).ReturnsAsync((int?)null);

        // Act
        var result = await _controller.GetAll(null, null);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<IEnumerable<SubjectDto>>(ok.Value).ToList();
        Assert.Empty(list);
    }

    [Fact]
    public async Task GetAll_Admin_SeesAllSubjects()
    {
        // Arrange
        SetHttpContext(RoleUtils.Admin, _adminId);

        // Act
        var result = await _controller.GetAll(null, null);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<IEnumerable<SubjectDto>>(ok.Value).ToList();
        Assert.Equal(2, list.Count);
        _scopingMock.Verify(s => s.GetProgramIdAsync(It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task GetAll_Registrar_SeesAllSubjects()
    {
        // Arrange
        SetHttpContext(RoleUtils.Registrar, _registrarId);

        // Act
        var result = await _controller.GetAll(null, null);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<IEnumerable<SubjectDto>>(ok.Value).ToList();
        Assert.Equal(2, list.Count);
    }

    // ── GetById: Program Head sees own program only ───────────────────────────

    [Fact]
    public async Task GetById_ProgramHead_CanAccessSubjectInOwnProgram()
    {
        // Arrange
        SetHttpContext(RoleUtils.ProgramHead, _programHeadId);
        _scopingMock.Setup(s => s.GetProgramIdAsync(_programHeadId)).ReturnsAsync(Program1);

        // Act
        var result = await _controller.GetById(_subjectProgram1);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var dto = Assert.IsType<SubjectDto>(ok.Value);
        Assert.Equal("IT101", dto.SubjectCode);
    }

    [Fact]
    public async Task GetById_ProgramHead_CannotAccessSubjectInOtherProgram_Returns403()
    {
        // Arrange
        SetHttpContext(RoleUtils.ProgramHead, _programHeadId);
        _scopingMock.Setup(s => s.GetProgramIdAsync(_programHeadId)).ReturnsAsync(Program1);

        // Act – _subjectProgram2 belongs to Program2
        var result = await _controller.GetById(_subjectProgram2);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task GetById_ProgramHead_NoProgram_Returns403()
    {
        // Arrange
        SetHttpContext(RoleUtils.ProgramHead, _programHeadId);
        _scopingMock.Setup(s => s.GetProgramIdAsync(_programHeadId)).ReturnsAsync((int?)null);

        // Act
        var result = await _controller.GetById(_subjectProgram1);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task GetById_Admin_CanAccessAnySubject()
    {
        // Arrange
        SetHttpContext(RoleUtils.Admin, _adminId);

        // Act
        var result = await _controller.GetById(_subjectProgram2);

        // Assert
        var ok = Assert.IsType<OkObjectResult>(result);
        var dto = Assert.IsType<SubjectDto>(ok.Value);
        Assert.Equal("CS101", dto.SubjectCode);
        _scopingMock.Verify(s => s.GetProgramIdAsync(It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task GetById_UnknownId_Returns404()
    {
        // Arrange
        SetHttpContext(RoleUtils.Admin, _adminId);

        // Act
        var result = await _controller.GetById(Guid.NewGuid());

        // Assert
        Assert.IsType<NotFoundObjectResult>(result);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ClassService.GetAllAsync – integration-level tests with real DB
// Verifies yearLevel filter and YearLevel property on ClassDto
// ─────────────────────────────────────────────────────────────────────────────

public class ClassServiceVisibilityTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly ClassService _service;

    private readonly Guid _termId = Guid.NewGuid();
    private readonly Guid _subjectYear1Id = Guid.NewGuid();
    private readonly Guid _subjectYear2Id = Guid.NewGuid();
    private readonly Guid _classYear1Id = Guid.NewGuid();
    private readonly Guid _classYear2Id = Guid.NewGuid();
    private readonly Guid _teacherId = Guid.NewGuid();
    private readonly Guid _studentId = Guid.NewGuid();

    public ClassServiceVisibilityTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        SeedData();

        var classRepo = new ClassRepository(_context);
        var scheduleRepo = new ClassScheduleRepository(_context);
        _service = new ClassService(_context, classRepo, scheduleRepo);
    }

    private void SeedData()
    {
        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _termId, SchoolYear = "2024-2025", Semester = 1 });
        _context.Users.Add(new User
        {
            UserID = _teacherId,
            FirebaseUID = "fb-teacher",
            Email = "teacher@test.edu",
            Role = RoleUtils.Teacher,
            IsActive = true
        });
        _context.Subjects.AddRange(
            new Subject { SubjectID = _subjectYear1Id, SubjectCode = "IT101", SubjectTitle = "Intro IT", ProgramID = 1, YearLevel = 1, DefaultSemester = 1 },
            new Subject { SubjectID = _subjectYear2Id, SubjectCode = "IT201", SubjectTitle = "Data Structures", ProgramID = 1, YearLevel = 2, DefaultSemester = 1 }
        );
        _context.Classes.AddRange(
            new Class
            {
                ClassID = _classYear1Id,
                SubjectID = _subjectYear1Id,
                TermID = _termId,
                ClassName = "BSIT-1A",
                UserID = _teacherId,
                CreatedAt = DateTime.UtcNow
            },
            new Class
            {
                ClassID = _classYear2Id,
                SubjectID = _subjectYear2Id,
                TermID = _termId,
                ClassName = "BSIT-2A",
                UserID = _teacherId,
                CreatedAt = DateTime.UtcNow
            }
        );
        // Student enrolled in year-1 class only
        _context.StudyLoads.Add(new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = _studentId,
            ClassID = _classYear1Id,
            LoadStatus = StudyLoadStatus.Enrolled
        });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    [Fact]
    public async Task GetAllAsync_YearLevelFilter_ReturnsOnlyMatchingClasses()
    {
        // Act
        var result = await _service.GetAllAsync(yearLevel: 1);

        // Assert
        Assert.Single(result);
        Assert.Equal(_classYear1Id, result[0].ClassID);
    }

    [Fact]
    public async Task GetAllAsync_YearLevelFilter2_ReturnsYear2Only()
    {
        // Act
        var result = await _service.GetAllAsync(yearLevel: 2);

        // Assert
        Assert.Single(result);
        Assert.Equal(_classYear2Id, result[0].ClassID);
    }

    [Fact]
    public async Task GetAllAsync_NoFilter_ReturnsBothClasses()
    {
        // Act
        var result = await _service.GetAllAsync();

        // Assert
        Assert.Equal(2, result.Count);
    }

    [Fact]
    public async Task GetAllAsync_YearLevelMapped_InClassDto()
    {
        // Act
        var result = await _service.GetAllAsync();

        // Assert — YearLevel is correctly populated from Subject.YearLevel
        var class1 = result.First(c => c.ClassID == _classYear1Id);
        var class2 = result.First(c => c.ClassID == _classYear2Id);
        Assert.Equal(1, class1.YearLevel);
        Assert.Equal(2, class2.YearLevel);
    }

    [Fact]
    public async Task GetAllAsync_StudentScope_ReturnsOnlyEnrolledClasses()
    {
        // Act
        var result = await _service.GetAllAsync(studentUserId: _studentId);

        // Assert — student only has StudyLoad for year-1 class
        Assert.Single(result);
        Assert.Equal(_classYear1Id, result[0].ClassID);
    }

    [Fact]
    public async Task GetAllAsync_StudentScopeWithYearLevelFilter_Intersects()
    {
        // Act – student enrolled in year-1 only, filtering by year-2 gives empty
        var result = await _service.GetAllAsync(studentUserId: _studentId, yearLevel: 2);

        // Assert
        Assert.Empty(result);
    }

    // ── CanAccessClassAsync: Service-level Tests ──────────────────────────────

    [Theory]
    [InlineData(RoleUtils.Admin)]
    [InlineData(RoleUtils.Registrar)]
    [InlineData(RoleUtils.CollegeHead)]
    public async Task CanAccessClassAsync_AdminRegistrarCollegeHead_AlwaysReturnsTrue(int role)
    {
        var result = await _service.CanAccessClassAsync(_classYear1Id, Guid.NewGuid(), role);
        Assert.True(result);
    }

    [Fact]
    public async Task CanAccessClassAsync_Teacher_OwnClass_ReturnsTrue()
    {
        var result = await _service.CanAccessClassAsync(_classYear1Id, _teacherId, RoleUtils.Teacher);
        Assert.True(result);
    }

    [Fact]
    public async Task CanAccessClassAsync_Teacher_OtherClass_ReturnsFalse()
    {
        var otherTeacher = Guid.NewGuid();
        var result = await _service.CanAccessClassAsync(_classYear1Id, otherTeacher, RoleUtils.Teacher);
        Assert.False(result);
    }

    [Fact]
    public async Task CanAccessClassAsync_Student_Enrolled_ReturnsTrue()
    {
        var result = await _service.CanAccessClassAsync(_classYear1Id, _studentId, RoleUtils.Student);
        Assert.True(result);
    }

    [Fact]
    public async Task CanAccessClassAsync_Student_NotEnrolled_ReturnsFalse()
    {
        var result = await _service.CanAccessClassAsync(_classYear2Id, _studentId, RoleUtils.Student);
        Assert.False(result);
    }

    [Fact]
    public async Task CanAccessClassAsync_ProgramHead_OwnProgram_ReturnsTrue()
    {
        // Arrange: Program Head with ProgramID = 1
        var phId = Guid.NewGuid();
        _context.UserDetails.Add(new UserDetails
        {
            UserID = phId,
            Firstname = "PH",
            Lastname = "One",
            ProgramID = 1
        });
        await _context.SaveChangesAsync();

        var result = await _service.CanAccessClassAsync(_classYear1Id, phId, RoleUtils.ProgramHead);
        Assert.True(result);
    }

    [Fact]
    public async Task CanAccessClassAsync_ProgramHead_OtherProgramNotTeaching_ReturnsFalse()
    {
        // Arrange: Program Head with ProgramID = 2 (classYear1 is in Program 1)
        var phId = Guid.NewGuid();
        _context.UserDetails.Add(new UserDetails
        {
            UserID = phId,
            Firstname = "PH",
            Lastname = "Two",
            ProgramID = 2
        });
        await _context.SaveChangesAsync();

        var result = await _service.CanAccessClassAsync(_classYear1Id, phId, RoleUtils.ProgramHead);
        Assert.False(result);
    }

    [Fact]
    public async Task CanAccessClassAsync_ProgramHead_ClassTheyTeachOutsideProgram_ReturnsTrue()
    {
        // Arrange: Program Head with ProgramID = 2, but teaching classYear1 (in Program 1)
        var phId = Guid.NewGuid();
        _context.UserDetails.Add(new UserDetails
        {
            UserID = phId,
            Firstname = "PH",
            Lastname = "Two",
            ProgramID = 2
        });
        var classInProg1 = await _context.Classes.FindAsync(_classYear1Id);
        classInProg1!.UserID = phId;
        await _context.SaveChangesAsync();

        var result = await _service.CanAccessClassAsync(_classYear1Id, phId, RoleUtils.ProgramHead);
        Assert.True(result);
    }

    [Fact]
    public async Task CanAccessClassAsync_ProgramHead_UnassignedProgram_ReturnsFalse()
    {
        var phId = Guid.NewGuid();
        _context.UserDetails.Add(new UserDetails
        {
            UserID = phId,
            Firstname = "PH",
            Lastname = "None",
            ProgramID = null
        });
        await _context.SaveChangesAsync();

        var result = await _service.CanAccessClassAsync(_classYear1Id, phId, RoleUtils.ProgramHead);
        Assert.False(result);
    }
}
