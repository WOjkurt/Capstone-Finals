using Api.Auth;
using Api.Controllers;
using Api.Domain.IdentityAccess;
using Api.Repositories;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

public class MeControllerTests
{
    private static (MeController, AppDbContext) Build(Guid userId)
    {
        var context = new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var controller = new MeController(new UserDetailsRepository(context));
        var http = new DefaultHttpContext();
        http.Items["user_id"] = userId;
        http.Items["email"] = "r@dbtc-cebu.edu.ph";
        http.Items["role"] = RoleUtils.Registrar;
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        return (controller, context);
    }

    private static object? Field(IActionResult result, string name)
    {
        var value = Assert.IsType<OkObjectResult>(result).Value!;
        return value.GetType().GetProperty(name)!.GetValue(value);
    }

    [Fact]
    public async Task ReturnsFullName_WhenDetailsExist()
    {
        var id = Guid.NewGuid();
        var (controller, context) = Build(id);
        context.Users.Add(new User { UserID = id, FirebaseUID = "fb", Email = "r@dbtc-cebu.edu.ph", Role = RoleUtils.Registrar, IsActive = true });
        context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = id, Firstname = "Rita", Lastname = "Reg" });
        await context.SaveChangesAsync();

        var result = await controller.GetCurrentUserInfo();

        Assert.Equal("Rita Reg", Field(result, "fullName"));
        Assert.Equal("Registrar", Field(result, "roleName"));
    }

    [Fact]
    public async Task FullNameIsNull_WhenNoDetails()
    {
        var (controller, _) = Build(Guid.NewGuid());

        var result = await controller.GetCurrentUserInfo();

        Assert.Null(Field(result, "fullName"));
    }
}
