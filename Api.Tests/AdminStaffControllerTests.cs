using Api.Controllers;
using Api.DTOs.Admin;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Api.Tests;

public class AdminStaffControllerTests
{
    private readonly Mock<IStaffService> _staffServiceMock;
    private readonly AdminStaffController _controller;

    public AdminStaffControllerTests()
    {
        _staffServiceMock = new Mock<IStaffService>();
        _controller = new AdminStaffController(_staffServiceMock.Object);
    }

    private void SetHttpContext(Guid? adminUserId = null)
    {
        var httpContext = new DefaultHttpContext();
        if (adminUserId.HasValue)
        {
            httpContext.Items["user_id"] = adminUserId.Value;
        }
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = httpContext
        };
    }

    [Fact]
    public async Task UpdateStaff_NoAuth_ReturnsUnauthorized()
    {
        // Arrange
        SetHttpContext(adminUserId: null);

        // Act
        var result = await _controller.UpdateStaff(Guid.NewGuid(), new UpdateStaffDto());

        // Assert
        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    [Fact]
    public async Task UpdateStaff_ValidRequest_ReturnsOkWithUpdatedStaff()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var targetStaffId = Guid.NewGuid();
        SetHttpContext(adminId);

        var dto = new UpdateStaffDto { Firstname = "Jane" };
        var expectedResponse = new StaffResponseDto
        {
            UserID = targetStaffId,
            Firstname = "Jane",
            Email = "jane@dbtc-cebu.edu.ph"
        };

        _staffServiceMock.Setup(s => s.UpdateStaffAsync(targetStaffId, dto, adminId))
            .ReturnsAsync(expectedResponse);

        // Act
        var result = await _controller.UpdateStaff(targetStaffId, dto);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var returnedStaff = Assert.IsType<StaffResponseDto>(okResult.Value);
        Assert.Equal("Jane", returnedStaff.Firstname);
    }

    [Fact]
    public async Task UpdateStaff_TargetNotFound_ReturnsNotFound()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var targetStaffId = Guid.NewGuid();
        SetHttpContext(adminId);

        var dto = new UpdateStaffDto { Firstname = "Jane" };

        _staffServiceMock.Setup(s => s.UpdateStaffAsync(targetStaffId, dto, adminId))
            .ThrowsAsync(new KeyNotFoundException("Staff user not found"));

        // Act
        var result = await _controller.UpdateStaff(targetStaffId, dto);

        // Assert
        Assert.IsType<NotFoundObjectResult>(result);
    }

    [Fact]
    public async Task UpdateStaff_InvalidOperation_ReturnsBadRequest()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var targetStaffId = Guid.NewGuid();
        SetHttpContext(adminId);

        var dto = new UpdateStaffDto { Role = 1 }; // Admin role invalid

        _staffServiceMock.Setup(s => s.UpdateStaffAsync(targetStaffId, dto, adminId))
            .ThrowsAsync(new InvalidOperationException("Invalid role."));

        // Act
        var result = await _controller.UpdateStaff(targetStaffId, dto);

        // Assert
        Assert.IsType<BadRequestObjectResult>(result);
    }
}
