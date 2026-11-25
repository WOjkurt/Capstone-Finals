using Api.Repositories;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Api.Auth;

/// <summary>
/// For verifying a class's grade sheet, and nothing else.
///
/// It exists rather than widening <see cref="RequireProgramHeadCollegeHeadOrAdminAttribute"/>,
/// which also guards creating classes and schedules -- work the Registrar has no business doing.
/// The Registrar is let in here because at DBTC the marks are encoded in her office, so the
/// second pass over them happens there too. Who she is, specifically, still matters: the service
/// refuses a sheet whose marks she encoded or corrected herself.
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false)]
public class RequireRegistrarProgramHeadCollegeHeadOrAdminAttribute
    : Attribute, IAsyncActionFilter, IOrderedFilter
{
    public int Order => AuthFilterOrder.RoleCheck;

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var httpContext = context.HttpContext;

        if (!httpContext.Items.TryGetValue("user_id", out var userIdObj)
            || userIdObj is not Guid userId || userId == Guid.Empty)
        {
            context.Result = new ObjectResult(new { message = "Authentication required." })
            {
                StatusCode = StatusCodes.Status401Unauthorized
            };
            return;
        }

        var userRepo = httpContext.RequestServices.GetRequiredService<IUserRepository>();
        var user = await userRepo.GetByIdAsync(userId);

        if (user is null
            || (user.Role != RoleUtils.Registrar
                && user.Role != RoleUtils.ProgramHead
                && user.Role != RoleUtils.CollegeHead
                && user.Role != RoleUtils.Admin))
        {
            context.Result = new ObjectResult(new
            {
                message = "Access denied. Registrar, Program Head, College Head, or Admin privileges required."
            })
            {
                StatusCode = StatusCodes.Status403Forbidden
            };
            return;
        }

        await next();
    }
}
