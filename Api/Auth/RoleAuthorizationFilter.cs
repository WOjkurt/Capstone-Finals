using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Api.Auth;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
public class RoleAuthorizationAttribute : Attribute, IAsyncActionFilter, IOrderedFilter
{
    public int Order => AuthFilterOrder.RoleCheck;

    private readonly int[] _allowedRoles;

    public RoleAuthorizationAttribute(params int[] allowedRoles)
    {
        _allowedRoles = allowedRoles;
    }

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var httpContext = context.HttpContext;

        if (!httpContext.Items.TryGetValue("role", out var userRoleObj) ||
            userRoleObj is not int userRole)
        {
            context.Result = new StatusCodeResult(StatusCodes.Status401Unauthorized);
            return;
        }

        if (_allowedRoles.Length > 0 && !_allowedRoles.Contains(userRole))
        {
            context.Result = new StatusCodeResult(StatusCodes.Status403Forbidden);
            return;
        }

        await next();
    }
}
