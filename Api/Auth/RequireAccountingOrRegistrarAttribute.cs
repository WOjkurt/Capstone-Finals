using Api.Repositories;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Api.Auth;

/// <summary>
/// The endpoints the Accounting Office shares with the Registrar: looking a student up, and
/// raising or lifting a hold.
///
/// Sharing an endpoint is not sharing its full behaviour. Accounting is confined to the
/// <see cref="Api.Domain.Enrollment.EnrollmentHoldReasons.UnpaidBalance"/> reason, which the
/// service enforces rather than this filter -- an attribute can say who may call an action,
/// not which arguments they may call it with.
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false)]
public class RequireAccountingOrRegistrarAttribute : Attribute, IAsyncActionFilter, IOrderedFilter
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

        // Read the role from the database rather than the request, matching the other role
        // attributes: a role changed or revoked mid-session takes effect on the next call.
        var userRepo = httpContext.RequestServices.GetRequiredService<IUserRepository>();
        var user = await userRepo.GetByIdAsync(userId);

        if (user is null ||
            (user.Role != RoleUtils.Accounting && user.Role != RoleUtils.Registrar && user.Role != RoleUtils.Admin))
        {
            context.Result = new ObjectResult(new { message = "Access denied. Accounting, Registrar, or Admin privileges required." })
            {
                StatusCode = StatusCodes.Status403Forbidden
            };
            return;
        }

        await next();
    }
}
