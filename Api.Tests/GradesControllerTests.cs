using Api.Auth;
using Api.Controllers;
using Api.DTOs.Grading;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Tests for <see cref="GradesController.GetByStudyLoad"/> covering the ownership
/// and clearance-masking checks introduced to fix the Critical IDOR/bypass finding.
/// </summary>
public class GradesControllerTests
{
    private readonly Mock<IGradeService> _gradeServiceMock;
    private readonly GradesController _controller;

    public GradesControllerTests()
    {
        _gradeServiceMock = new Mock<IGradeService>();
        _controller = new GradesController(_gradeServiceMock.Object);
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

    // ─── Helper: a minimal grade DTO to return when a call is permitted ────────

    private static GradeResponseDto SampleGrade(Guid studyLoadId) => new()
    {
        GradeId = Guid.NewGuid(),
        StudyLoadId = studyLoadId,
        MidtermGrade = 1.5m,
        FinalGrade = null,
        Remarks = null,
        RemarksLabel = null
    };

    // ══════════════════════════════════════════════════════════════════════════
    //  A — STUDENT: own study load, grade cleared
    // ══════════════════════════════════════════════════════════════════════════

    [Fact]
    public async Task GetByStudyLoad_StudentOwner_Cleared_ReturnsOk()
    {
        // Arrange
        var studentId = Guid.NewGuid();
        var studyLoadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Student, studentId);

        _gradeServiceMock
            .Setup(s => s.GetByStudyLoadIdAsync(studyLoadId, studentId, RoleUtils.Student))
            .ReturnsAsync(SampleGrade(studyLoadId));

        // Act
        var result = await _controller.GetByStudyLoad(studyLoadId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _gradeServiceMock.Verify(
            s => s.GetByStudyLoadIdAsync(studyLoadId, studentId, RoleUtils.Student), Times.Once);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  A — STUDENT: own study load, NOT cleared → 403 (bypass fix)
    // ══════════════════════════════════════════════════════════════════════════

    [Fact]
    public async Task GetByStudyLoad_StudentOwner_NotCleared_Returns403()
    {
        // Arrange
        var studentId = Guid.NewGuid();
        var studyLoadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Student, studentId);

        // Service enforces clearance and throws; controller must surface 403
        _gradeServiceMock
            .Setup(s => s.GetByStudyLoadIdAsync(studyLoadId, studentId, RoleUtils.Student))
            .ThrowsAsync(new UnauthorizedAccessException(
                "Your grades for this term are withheld pending clearance. Please contact the Registrar."));

        // Act
        var result = await _controller.GetByStudyLoad(studyLoadId);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  IDOR — Student trying to view another student's grade → 403
    // ══════════════════════════════════════════════════════════════════════════

    [Fact]
    public async Task GetByStudyLoad_StudentRequestingAnotherStudentGrade_Returns403()
    {
        // Arrange — attacker is a different student from the owner of studyLoadId
        var attackerId = Guid.NewGuid();
        var studyLoadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Student, attackerId);

        _gradeServiceMock
            .Setup(s => s.GetByStudyLoadIdAsync(studyLoadId, attackerId, RoleUtils.Student))
            .ThrowsAsync(new UnauthorizedAccessException(
                "Access denied. You can only view your own grades."));

        // Act
        var result = await _controller.GetByStudyLoad(studyLoadId);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  B — Teacher who IS assigned to the class → 200 OK (no clearance needed)
    // ══════════════════════════════════════════════════════════════════════════

    [Fact]
    public async Task GetByStudyLoad_AssignedTeacher_ReturnsOk()
    {
        // Arrange
        var teacherId = Guid.NewGuid();
        var studyLoadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Teacher, teacherId);

        _gradeServiceMock
            .Setup(s => s.GetByStudyLoadIdAsync(studyLoadId, teacherId, RoleUtils.Teacher))
            .ReturnsAsync(SampleGrade(studyLoadId));

        // Act
        var result = await _controller.GetByStudyLoad(studyLoadId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  B — Teacher who is NOT assigned to this class → 403
    // ══════════════════════════════════════════════════════════════════════════

    [Fact]
    public async Task GetByStudyLoad_UnassignedTeacher_Returns403()
    {
        // Arrange
        var wrongTeacherId = Guid.NewGuid();
        var studyLoadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Teacher, wrongTeacherId);

        _gradeServiceMock
            .Setup(s => s.GetByStudyLoadIdAsync(studyLoadId, wrongTeacherId, RoleUtils.Teacher))
            .ThrowsAsync(new UnauthorizedAccessException(
                "Access denied. You are not the assigned teacher for this class."));

        // Act
        var result = await _controller.GetByStudyLoad(studyLoadId);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  C — Registrar: no restrictions → 200 OK
    // ══════════════════════════════════════════════════════════════════════════

    [Fact]
    public async Task GetByStudyLoad_Registrar_ReturnsOk()
    {
        // Arrange
        var registrarId = Guid.NewGuid();
        var studyLoadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Registrar, registrarId);

        _gradeServiceMock
            .Setup(s => s.GetByStudyLoadIdAsync(studyLoadId, registrarId, RoleUtils.Registrar))
            .ReturnsAsync(SampleGrade(studyLoadId));

        // Act
        var result = await _controller.GetByStudyLoad(studyLoadId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  C — Admin: no restrictions → 200 OK
    // ══════════════════════════════════════════════════════════════════════════

    [Fact]
    public async Task GetByStudyLoad_Admin_ReturnsOk()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var studyLoadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);

        _gradeServiceMock
            .Setup(s => s.GetByStudyLoadIdAsync(studyLoadId, adminId, RoleUtils.Admin))
            .ReturnsAsync(SampleGrade(studyLoadId));

        // Act
        var result = await _controller.GetByStudyLoad(studyLoadId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  Grade not found → 404
    // ══════════════════════════════════════════════════════════════════════════

    [Fact]
    public async Task GetByStudyLoad_GradeNotFound_Returns404()
    {
        // Arrange
        var registrarId = Guid.NewGuid();
        var studyLoadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Registrar, registrarId);

        _gradeServiceMock
            .Setup(s => s.GetByStudyLoadIdAsync(studyLoadId, registrarId, RoleUtils.Registrar))
            .ReturnsAsync((GradeResponseDto?)null);

        // Act
        var result = await _controller.GetByStudyLoad(studyLoadId);

        // Assert
        Assert.IsType<NotFoundObjectResult>(result);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  Missing auth context → 401
    // ══════════════════════════════════════════════════════════════════════════

    [Fact]
    public async Task GetByStudyLoad_MissingAuthContext_Returns401()
    {
        // Arrange — no HttpContext.Items populated at all
        var httpContext = new DefaultHttpContext();
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = httpContext
        };

        // Act
        var result = await _controller.GetByStudyLoad(Guid.NewGuid());

        // Assert
        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  Role-gate: [RequireTeacher] attribute decoration tests
    // ══════════════════════════════════════════════════════════════════════════

    [Fact]
    public void SubmitGrade_HasRequireTeacherAttribute()
    {
        // Act
        var method = typeof(GradesController).GetMethod(nameof(GradesController.SubmitGrade));
        var attribute = method?.GetCustomAttributes(typeof(RequireTeacherAttribute), inherit: false);

        // Assert
        Assert.NotNull(attribute);
        Assert.NotEmpty(attribute);
    }

    [Fact]
    public void SubmitGradeBatch_HasRequireTeacherAttribute()
    {
        // Act
        var method = typeof(GradesController).GetMethod(nameof(GradesController.SubmitGradeBatch));
        var attribute = method?.GetCustomAttributes(typeof(RequireTeacherAttribute), inherit: false);

        // Assert
        Assert.NotNull(attribute);
        Assert.NotEmpty(attribute);
    }

    [Theory]
    [InlineData(RoleUtils.Student)]
    [InlineData(RoleUtils.Registrar)]
    [InlineData(RoleUtils.Admin)]
    public async Task RequireTeacherAttribute_NonTeacherUser_Returns403Forbidden(int role)
    {
        // Arrange
        var userId = Guid.NewGuid();
        var userRepoMock = new Mock<Api.Repositories.IUserRepository>();
        userRepoMock.Setup(r => r.GetByIdAsync(userId))
            .ReturnsAsync(new Api.Domain.IdentityAccess.User
            {
                UserID = userId,
                Role = role,
                FirebaseUID = "test-uid",
                Email = "test@example.com"
            });

        var serviceProviderMock = new Mock<IServiceProvider>();
        serviceProviderMock.Setup(sp => sp.GetService(typeof(Api.Repositories.IUserRepository)))
            .Returns(userRepoMock.Object);

        var httpContext = new DefaultHttpContext
        {
            RequestServices = serviceProviderMock.Object
        };
        httpContext.Items["user_id"] = userId;

        var actionContext = new ActionContext(httpContext, new Microsoft.AspNetCore.Routing.RouteData(), new Microsoft.AspNetCore.Mvc.Abstractions.ActionDescriptor());
        var filterContext = new Microsoft.AspNetCore.Mvc.Filters.ActionExecutingContext(
            actionContext,
            new List<Microsoft.AspNetCore.Mvc.Filters.IFilterMetadata>(),
            new Dictionary<string, object?>(),
            controller: null!
        );

        bool nextCalled = false;
        var filter = new RequireTeacherAttribute();

        // Act
        await filter.OnActionExecutionAsync(filterContext, () =>
        {
            nextCalled = true;
            return Task.FromResult<Microsoft.AspNetCore.Mvc.Filters.ActionExecutedContext>(null!);
        });

        // Assert
        Assert.False(nextCalled);
        var objectResult = Assert.IsType<ObjectResult>(filterContext.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, objectResult.StatusCode);
    }

    [Fact]
    public async Task RequireTeacherAttribute_TeacherUser_ProceedsToNext()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var userRepoMock = new Mock<Api.Repositories.IUserRepository>();
        userRepoMock.Setup(r => r.GetByIdAsync(userId))
            .ReturnsAsync(new Api.Domain.IdentityAccess.User
            {
                UserID = userId,
                Role = RoleUtils.Teacher,
                FirebaseUID = "teacher-uid",
                Email = "teacher@example.com"
            });

        var serviceProviderMock = new Mock<IServiceProvider>();
        serviceProviderMock.Setup(sp => sp.GetService(typeof(Api.Repositories.IUserRepository)))
            .Returns(userRepoMock.Object);

        var httpContext = new DefaultHttpContext
        {
            RequestServices = serviceProviderMock.Object
        };
        httpContext.Items["user_id"] = userId;

        var actionContext = new ActionContext(httpContext, new Microsoft.AspNetCore.Routing.RouteData(), new Microsoft.AspNetCore.Mvc.Abstractions.ActionDescriptor());
        var filterContext = new Microsoft.AspNetCore.Mvc.Filters.ActionExecutingContext(
            actionContext,
            new List<Microsoft.AspNetCore.Mvc.Filters.IFilterMetadata>(),
            new Dictionary<string, object?>(),
            controller: null!
        );

        bool nextCalled = false;
        var filter = new RequireTeacherAttribute();

        // Act
        await filter.OnActionExecutionAsync(filterContext, () =>
        {
            nextCalled = true;
            return Task.FromResult<Microsoft.AspNetCore.Mvc.Filters.ActionExecutedContext>(null!);
        });

        // Assert
        Assert.True(nextCalled);
        Assert.Null(filterContext.Result);
    }
}
