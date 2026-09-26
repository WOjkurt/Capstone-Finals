using Api.Auth;
using Api.Controllers;
using Api.Domain.IdentityAccess;
using Api.DTOs.Grading;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
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

    [Fact]
    public async Task SetClearance_KeyNotFoundException_Returns404NotFound()
    {
        // Arrange
        var registrarId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Registrar, registrarId);

        _clearanceServiceMock.Setup(s => s.SetClearanceAsync(studentId, termId, true, registrarId))
            .ThrowsAsync(new KeyNotFoundException("User not found."));

        // Act
        var result = await _controller.SetClearance(studentId, termId, new SetGradeClearanceDto { IsCleared = true });

        // Assert
        var notFoundResult = Assert.IsType<NotFoundObjectResult>(result);
        Assert.Equal(StatusCodes.Status404NotFound, notFoundResult.StatusCode);
    }

    [Fact]
    public async Task SetClearance_InvalidOperationException_ReturnsBadRequest()
    {
        // Arrange
        var registrarId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Registrar, registrarId);

        _clearanceServiceMock.Setup(s => s.SetClearanceAsync(studentId, termId, true, registrarId))
            .ThrowsAsync(new InvalidOperationException("Clearance cannot be modified for closed term."));

        // Act
        var result = await _controller.SetClearance(studentId, termId, new SetGradeClearanceDto { IsCleared = true });

        // Assert
        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [Fact]
    public async Task SetClearance_UnexpectedException_BubblesUpToGlobalHandler()
    {
        // Arrange — an unexpected DB or network exception that should NOT be swallowed as BadRequest(ex.Message)
        var registrarId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Registrar, registrarId);

        _clearanceServiceMock.Setup(s => s.SetClearanceAsync(studentId, termId, true, registrarId))
            .ThrowsAsync(new Exception("Database connection failed: Sensitive connection string details"));

        // Act & Assert — Must bubble up so the global exception handler catches and sanitizes it
        await Assert.ThrowsAsync<Exception>(() =>
            _controller.SetClearance(studentId, termId, new SetGradeClearanceDto { IsCleared = true }));
    }

    [Fact]
    public async Task CreateClearance_ValidRequest_Returns201Created()
    {
        // Arrange
        var registrarId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Registrar, registrarId);

        var dto = new CreateGradeClearanceDto { UserId = studentId, TermId = termId, IsCleared = false };
        var responseDto = new GradeClearanceResponseDto
        {
            ClearanceID = Guid.NewGuid(),
            UserID = studentId,
            TermID = termId,
            IsCleared = false
        };

        _clearanceServiceMock
            .Setup(s => s.CreateClearanceAsync(studentId, termId, false, registrarId))
            .ReturnsAsync(responseDto);

        // Act
        var result = await _controller.CreateClearance(dto);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status201Created, statusResult.StatusCode);
        _clearanceServiceMock.Verify(
            s => s.CreateClearanceAsync(studentId, termId, false, registrarId), Times.Once);
    }

    [Fact]
    public async Task CreateClearance_RecordAlreadyExists_Returns409Conflict()
    {
        // Arrange
        var registrarId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Registrar, registrarId);

        var dto = new CreateGradeClearanceDto { UserId = studentId, TermId = termId };

        _clearanceServiceMock
            .Setup(s => s.CreateClearanceAsync(studentId, termId, false, registrarId))
            .ThrowsAsync(new InvalidOperationException(
                "A grade clearance record already exists for this student and academic term."));

        // Act
        var result = await _controller.CreateClearance(dto);

        // Assert
        var conflictResult = Assert.IsType<ConflictObjectResult>(result);
        Assert.Equal(StatusCodes.Status409Conflict, conflictResult.StatusCode);
    }

    [Fact]
    public async Task CreateClearance_NoAuthenticatedUser_Returns401Unauthorized()
    {
        // Arrange — HttpContext.Items has no "user_id" key (simulates a caller whose
        // auth token was missing or whose JWT was not decoded into Items by middleware).
        var httpContext = new DefaultHttpContext();
        // Deliberately do NOT set "user_id" in Items
        _controller.ControllerContext = new ControllerContext { HttpContext = httpContext };

        var dto = new CreateGradeClearanceDto { UserId = Guid.NewGuid(), TermId = Guid.NewGuid() };

        // Act
        var result = await _controller.CreateClearance(dto);

        // Assert — must get 401 before the service is ever called
        Assert.IsType<UnauthorizedObjectResult>(result);
        _clearanceServiceMock.Verify(
            s => s.CreateClearanceAsync(
                It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<Guid>()),
            Times.Never);
    }

    [Theory]
    [InlineData(RoleUtils.Teacher)]
    [InlineData(RoleUtils.Student)]
    public async Task CreateClearance_AuthenticatedAsNonRegistrarNonAdmin_Returns403Forbidden(int nonAuthorizedRole)
    {
        // 1. Confirm the endpoint is protected by [RequireRegistrarOrAdmin]
        var actionMethod = typeof(GradeClearancesController).GetMethod(nameof(GradeClearancesController.CreateClearance));
        var filterAttr = actionMethod?.GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), false)
            .FirstOrDefault() as RequireRegistrarOrAdminAttribute;
        Assert.NotNull(filterAttr);

        // 2. Execute the filter with a non-Registrar / non-Admin caller (Teacher or Student)
        var callerId = Guid.NewGuid();
        var userRepoMock = new Mock<IUserRepository>();
        userRepoMock.Setup(r => r.GetByIdAsync(callerId))
            .ReturnsAsync(new User
            {
                UserID = callerId,
                Role = nonAuthorizedRole,
                Email = "user@school.edu",
                FirebaseUID = "firebase-uid"
            });

        var serviceProviderMock = new Mock<IServiceProvider>();
        serviceProviderMock.Setup(sp => sp.GetService(typeof(IUserRepository)))
            .Returns(userRepoMock.Object);

        var httpContext = new DefaultHttpContext { RequestServices = serviceProviderMock.Object };
        httpContext.Items["user_id"] = callerId;
        httpContext.Items["role"] = nonAuthorizedRole;

        var actionExecutingContext = new ActionExecutingContext(
            new ActionContext(httpContext, new RouteData(), new ActionDescriptor()),
            new List<IFilterMetadata>(),
            new Dictionary<string, object?>(),
            _controller);

        bool nextCalled = false;
        ActionExecutionDelegate next = () =>
        {
            nextCalled = true;
            return Task.FromResult<ActionExecutedContext>(null!);
        };

        // Act — The action filter runs as part of the request pipeline before the action
        await filterAttr.OnActionExecutionAsync(actionExecutingContext, next);

        // Assert — Filter returns 403 Forbidden and short-circuits (next is NEVER called)
        Assert.False(nextCalled);
        var statusResult = Assert.IsType<ObjectResult>(actionExecutingContext.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }
}

