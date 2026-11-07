using Api.Repositories;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Api.Auth;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false)]
public class RequireProgramHeadCollegeHeadOrAdminAttribute : Attribute, IAsyncActionFilter, IOrderedFilter
{
    public int Order => AuthFilterOrder.RoleCheck;

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var httpContext = context.HttpContext;

        if (!httpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid userId || userId == Guid.Empty)
        {
            context.Result = new ObjectResult(new { message = "Authentication required." })
            {
                StatusCode = StatusCodes.Status401Unauthorized
            };
            return;
        }

        var userRepo = httpContext.RequestServices.GetRequiredService<IUserRepository>();
        var user = await userRepo.GetByIdAsync(userId);

        if (user is null || (user.Role != RoleUtils.ProgramHead && user.Role != RoleUtils.CollegeHead && user.Role != RoleUtils.Admin))
        {
            context.Result = new ObjectResult(new { message = "Access denied. Program Head, College Head, or Admin privileges required." })
            {
                StatusCode = StatusCodes.Status403Forbidden
            };
            return;
        }

        await next();
    }
}
