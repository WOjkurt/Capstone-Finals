using Api.Auth;
using Api.Controllers;
using Api.Domain.IdentityAccess;
using Api.DTOs.Grading;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Api.Tests;

public class GradeClearancesControllerTests
{
    private readonly Mock<IGradeClearanceService> _clearanceServiceMock;
    private readonly Mock<IUserDetailsRepository> _userDetailsRepoMock;
    private readonly Mock<IProgramScopingService> _scopingServiceMock;
    private readonly GradeClearancesController _controller;

    public GradeClearancesControllerTests()
    {
        _clearanceServiceMock = new Mock<IGradeClearanceService>();
        _userDetailsRepoMock = new Mock<IUserDetailsRepository>();
        _scopingServiceMock = new Mock<IProgramScopingService>();

        _controller = new GradeClearancesController(
            _clearanceServiceMock.Object,
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
    public async Task GetByStudent_ProgramHeadViewingStudentInOwnProgram_ReturnsOk()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
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

        _clearanceServiceMock.Setup(s => s.GetByStudentAsync(studentId))
            .ReturnsAsync(new List<GradeClearanceResponseDto>());

        // Act
        var result = await _controller.GetByStudent(studentId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.EnsureProgramHeadAccessAsync(programHeadId, bsitProgramId, "student"), Times.Once);
    }

    [Fact]
    public async Task GetByStudent_ProgramHeadViewingStudentInOtherProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
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
        var result = await _controller.GetByStudent(studentId);

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
        SetHttpContext(RoleUtils.Admin, adminId);

        _clearanceServiceMock.Setup(s => s.GetByStudentAsync(studentId))
            .ReturnsAsync(new List<GradeClearanceResponseDto>());

        // Act
        var result = await _controller.GetByStudent(studentId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.EnsureProgramHeadAccessAsync(It.IsAny<Guid>(), It.IsAny<int?>(), It.IsAny<string>()), Times.Never);
    }
}
