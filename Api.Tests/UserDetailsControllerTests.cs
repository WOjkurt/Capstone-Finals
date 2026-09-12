using Api.Auth;
using Api.Controllers;
using Api.Domain.IdentityAccess;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Api.Tests;

public class UserDetailsControllerTests
{
    private readonly Mock<IUserDetailsRepository> _userDetailsRepoMock;
    private readonly UserDetailsController _controller;

    public UserDetailsControllerTests()
    {
        _userDetailsRepoMock = new Mock<IUserDetailsRepository>();
        _controller = new UserDetailsController(_userDetailsRepoMock.Object);
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
        SetHttpContext(RoleUtils.ProgramHead, Guid.NewGuid());
        _userDetailsRepoMock.Setup(r => r.SearchAsync(null, RoleUtils.Teacher))
            .ReturnsAsync(new List<UserDetails>
            {
                new()
                {
                    UserID = Guid.NewGuid(),
                    Firstname = "John",
                    Lastname = "Teacher",
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
    }

    [Fact]
    public async Task Search_RegistrarSearchingAnyRole_ReturnsOk()
    {
        // Arrange
        SetHttpContext(RoleUtils.Registrar, Guid.NewGuid());
        _userDetailsRepoMock.Setup(r => r.SearchAsync(null, null))
            .ReturnsAsync(new List<UserDetails>());

        // Act - Registrar can search without role restriction
        var result = await _controller.Search(null, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
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
