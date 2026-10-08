using Api.Auth;
using Api.Controllers;
using Api.Domain.IdentityAccess;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

public class UserDetailsControllerTests
{
    private readonly Mock<IUserDetailsRepository> _userDetailsRepoMock;
    private readonly Mock<IProgramScopingService> _scopingServiceMock;
    private readonly UserDetailsController _controller;

    public UserDetailsControllerTests()
    {
        _userDetailsRepoMock = new Mock<IUserDetailsRepository>();
        _scopingServiceMock = new Mock<IProgramScopingService>();
        _controller = new UserDetailsController(
            _userDetailsRepoMock.Object,
            _scopingServiceMock.Object,
            NullLogger<UserDetailsController>.Instance);
    }

    private void SetHttpContext(int? role, Guid? userId = null)
    {
        var httpContext = new DefaultHttpContext();
        if (role.HasValue)
        {
            httpContext.Items["role"] = role.Value;
        }
        if (userId.HasValue)
        {
            httpContext.Items["user_id"] = userId.Value;
        }
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = httpContext
        };
    }

    [Fact]
    public async Task Search_ProgramHeadSearchingTeachers_ReturnsOk()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        int programId = 1;
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        _scopingServiceMock.Setup(s => s.GetProgramIdAsync(programHeadId))
            .ReturnsAsync(programId);

        _userDetailsRepoMock.Setup(r => r.SearchAsync(null, RoleUtils.Teacher, programId, null))
            .ReturnsAsync(new List<UserDetails>
            {
                new()
                {
                    UserID = Guid.NewGuid(),
                    Firstname = "John",
                    Lastname = "Teacher",
                    ProgramID = programId,
                    User = new User
                    {
                        FirebaseUID = "firebase_teacher_1",
                        Email = "teacher@dbtc-cebu.edu.ph",
                        Role = RoleUtils.Teacher
                    }
                }
            });

        // Act
        var result = await _controller.Search(null, RoleUtils.Teacher);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var dtos = Assert.IsAssignableFrom<IEnumerable<UserSearchResultDto>>(okResult.Value);
        Assert.Single(dtos);
    }

    [Fact]
    public async Task Search_ProgramHeadSearchingTeachers_OnlyReturnsTeachersFromOwnProgram()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        int myProgramId = 1;
        int otherProgramId = 2;
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        _scopingServiceMock.Setup(s => s.GetProgramIdAsync(programHeadId))
            .ReturnsAsync(myProgramId);

        var ownProgramTeacher = new UserDetails
        {
            UserID = Guid.NewGuid(),
            Firstname = "Alice",
            Lastname = "Teacher",
            ProgramID = myProgramId,
            User = new User
            {
                FirebaseUID = "firebase_t1",
                Email = "alice@dbtc-cebu.edu.ph",
                Role = RoleUtils.Teacher
            }
        };

        // Repository returns only the scoped teacher when queried with myProgramId and null limit
        _userDetailsRepoMock.Setup(r => r.SearchAsync(null, RoleUtils.Teacher, myProgramId, null))
            .ReturnsAsync(new List<UserDetails> { ownProgramTeacher });

        // Act
        var result = await _controller.Search(null, RoleUtils.Teacher);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var dtos = Assert.IsAssignableFrom<IEnumerable<UserSearchResultDto>>(okResult.Value).ToList();

        Assert.Single(dtos);
        Assert.Equal(ownProgramTeacher.UserID, dtos[0].UserID);
        Assert.Equal(myProgramId, dtos[0].ProgramID);

        // Verify that SearchAsync was called with the Program Head's own program ID and no limit (null)
        _userDetailsRepoMock.Verify(r => r.SearchAsync(null, RoleUtils.Teacher, myProgramId, null), Times.Once);
        // Verify that other program or unscoped queries were never made
        _userDetailsRepoMock.Verify(r => r.SearchAsync(It.IsAny<string?>(), It.IsAny<int?>(), otherProgramId, It.IsAny<int?>()), Times.Never);
        _userDetailsRepoMock.Verify(r => r.SearchAsync(It.IsAny<string?>(), It.IsAny<int?>(), null, It.IsAny<int?>()), Times.Never);
    }

    [Fact]
    public async Task Search_ProgramHeadWithoutAssignedProgram_ReturnsEmptyList()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        _scopingServiceMock.Setup(s => s.GetProgramIdAsync(programHeadId))
            .ReturnsAsync((int?)null);

        // Act
        var result = await _controller.Search(null, RoleUtils.Teacher);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var dtos = Assert.IsAssignableFrom<IEnumerable<UserSearchResultDto>>(okResult.Value);
        Assert.Empty(dtos);
        _userDetailsRepoMock.Verify(r => r.SearchAsync(It.IsAny<string?>(), It.IsAny<int?>(), It.IsAny<int?>(), It.IsAny<int?>()), Times.Never);
    }

    [Theory]
    [InlineData(RoleUtils.Student)] // 1
    [InlineData(RoleUtils.Registrar)] // 2
    [InlineData(RoleUtils.ProgramHead)] // 4
    [InlineData(null)] // null role search
    public async Task Search_ProgramHeadSearchingNonTeacherRoles_Returns403Forbidden(int? targetRole)
    {
        // Arrange
        SetHttpContext(RoleUtils.ProgramHead, Guid.NewGuid());

        // Act
        var result = await _controller.Search(null, targetRole);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task Search_AdminSearchingAnyRole_ReturnsOk()
    {
        // Arrange
        SetHttpContext(RoleUtils.Admin, Guid.NewGuid());
        _userDetailsRepoMock.Setup(r => r.SearchAsync(null, RoleUtils.Student))
            .ReturnsAsync(new List<UserDetails>
            {
                new()
                {
                    UserID = Guid.NewGuid(),
                    Firstname = "Student",
                    Lastname = "User",
                    User = new User
                    {
                        FirebaseUID = "firebase_student_1",
                        Email = "student@dbtc-cebu.edu.ph",
                        Role = RoleUtils.Student
                    }
                }
            });

        // Act - Admin can search students
        var result = await _controller.Search(null, RoleUtils.Student);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var dtos = Assert.IsAssignableFrom<IEnumerable<UserSearchResultDto>>(okResult.Value);
        Assert.Single(dtos);
        _scopingServiceMock.Verify(s => s.GetProgramIdAsync(It.IsAny<Guid>()), Times.Never);
        _userDetailsRepoMock.Verify(r => r.SearchAsync(null, RoleUtils.Student, null, 50), Times.Once);
    }

    [Fact]
    public async Task Search_RegistrarSearchingAnyRole_ReturnsOk()
    {
        // Arrange
        SetHttpContext(RoleUtils.Registrar, Guid.NewGuid());
        _userDetailsRepoMock.Setup(r => r.SearchAsync(null, null, null, 50))
            .ReturnsAsync(new List<UserDetails>());

        // Act - Registrar can search without role restriction
        var result = await _controller.Search(null, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.GetProgramIdAsync(It.IsAny<Guid>()), Times.Never);
        _userDetailsRepoMock.Verify(r => r.SearchAsync(null, null, null, 50), Times.Once);
    }

    [Fact]
    public async Task Search_Unauthenticated_Returns401Unauthorized()
    {
        // Arrange (no role in HttpContext)
        SetHttpContext(null);

        // Act
        var result = await _controller.Search(null, RoleUtils.Teacher);

        // Assert
        Assert.IsType<UnauthorizedObjectResult>(result);
    }
}
