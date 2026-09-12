using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Api.Tests;

public class StudyLoadsControllerTests
{
    private readonly Mock<IStudyLoadService> _studyLoadServiceMock;
    private readonly Mock<IClassRepository> _classRepoMock;
    private readonly Mock<IUserDetailsRepository> _userDetailsRepoMock;
    private readonly Mock<IProgramScopingService> _scopingServiceMock;
    private readonly StudyLoadsController _controller;

    public StudyLoadsControllerTests()
    {
        _studyLoadServiceMock = new Mock<IStudyLoadService>();
        _classRepoMock = new Mock<IClassRepository>();
        _userDetailsRepoMock = new Mock<IUserDetailsRepository>();
        _scopingServiceMock = new Mock<IProgramScopingService>();

        _controller = new StudyLoadsController(
            _studyLoadServiceMock.Object,
            _classRepoMock.Object,
            _userDetailsRepoMock.Object,
            _scopingServiceMock.Object);
    }

    private void SetHttpContext(int role, Guid userId)
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Items["role"] = role;
        httpContext.Items["user_id"] = userId;
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = httpContext
        };
    }

    [Fact]
    public async Task GetByClass_ProgramHeadViewingRosterInOwnProgram_ReturnsOk()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        int bsitProgramId = 1;
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var classId = Guid.NewGuid();
        var targetClass = new Class
        {
            ClassID = classId,
            ClassName = "BSIT 1A",
            SubjectID = Guid.NewGuid(),
            Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = bsitProgramId, SubjectCode = "IT101", SubjectTitle = "Intro" }
        };

        _classRepoMock.Setup(r => r.GetByIdAsync(classId)).ReturnsAsync(targetClass);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, bsitProgramId, "class"))
            .Returns(Task.CompletedTask);

        _studyLoadServiceMock.Setup(s => s.GetByClassAsync(classId))
            .ReturnsAsync(new List<StudyLoadResponseDto>());

        // Act
        var result = await _controller.GetByClass(classId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.EnsureProgramHeadAccessAsync(programHeadId, bsitProgramId, "class"), Times.Once);
    }

    [Fact]
    public async Task GetByClass_ProgramHeadViewingRosterInOtherProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        int bsbaProgramId = 2;
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var classId = Guid.NewGuid();
        var targetClass = new Class
        {
            ClassID = classId,
            ClassName = "BSBA 2A",
            SubjectID = Guid.NewGuid(),
            Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = bsbaProgramId, SubjectCode = "BA201", SubjectTitle = "Finance" }
        };

        _classRepoMock.Setup(r => r.GetByIdAsync(classId)).ReturnsAsync(targetClass);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, bsbaProgramId, "class"))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied. You can only access classs belonging to your academic program."));

        // Act
        var result = await _controller.GetByClass(classId);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task GetByClass_AdminViewingRosterInAnyProgram_IsAllowed()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);

        var classId = Guid.NewGuid();
        var targetClass = new Class
        {
            ClassID = classId,
            ClassName = "BSBA 2A",
            SubjectID = Guid.NewGuid(),
            Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = 2, SubjectCode = "BA201", SubjectTitle = "Finance" }
        };

        _classRepoMock.Setup(r => r.GetByIdAsync(classId)).ReturnsAsync(targetClass);
        _studyLoadServiceMock.Setup(s => s.GetByClassAsync(classId))
            .ReturnsAsync(new List<StudyLoadResponseDto>());

        // Act
        var result = await _controller.GetByClass(classId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.EnsureProgramHeadAccessAsync(It.IsAny<Guid>(), It.IsAny<int?>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task GetByStudent_ProgramHeadViewingStudentInOwnProgram_ReturnsOk()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        int bsitProgramId = 1;
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var studentDetails = new UserDetails
        {
            UserID = studentId,
            ProgramID = bsitProgramId,
            Firstname = "John",
            Lastname = "Student"
        };

        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(studentId)).ReturnsAsync(studentDetails);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, bsitProgramId, "student"))
            .Returns(Task.CompletedTask);

        _studyLoadServiceMock.Setup(s => s.GetByStudentAsync(studentId, termId))
            .ReturnsAsync(new List<StudyLoadResponseDto>());

        // Act
        var result = await _controller.GetByStudent(studentId, termId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task GetByStudent_ProgramHeadViewingStudentInOtherProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        int bsbaProgramId = 2;
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var studentDetails = new UserDetails
        {
            UserID = studentId,
            ProgramID = bsbaProgramId,
            Firstname = "Alice",
            Lastname = "Student"
        };

        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(studentId)).ReturnsAsync(studentDetails);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, bsbaProgramId, "student"))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied."));

        // Act
        var result = await _controller.GetByStudent(studentId, termId);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task GetByStudent_AdminViewingStudent_IsAllowedWithoutScopingCheck()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);

        _studyLoadServiceMock.Setup(s => s.GetByStudentAsync(studentId, termId))
            .ReturnsAsync(new List<StudyLoadResponseDto>());

        // Act
        var result = await _controller.GetByStudent(studentId, termId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.EnsureProgramHeadAccessAsync(It.IsAny<Guid>(), It.IsAny<int?>(), It.IsAny<string>()), Times.Never);
    }
}
