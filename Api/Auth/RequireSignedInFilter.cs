using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Api.Auth;

/// <summary>
/// Added to every endpoint: no sign-in means 401, so a new endpoint is closed unless it says otherwise.
/// Only the Google Forms webhook opts out with [AllowAnonymous], and it has its own secret.
/// </summary>
public class RequireSignedInFilter : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        bool open = context.ActionDescriptor.EndpointMetadata.OfType<IAllowAnonymous>().Any();
        if (!open && !context.HttpContext.Items.ContainsKey("user_id"))
        {
            context.Result = new ObjectResult(new { message = "Authentication required." })
            {
                StatusCode = StatusCodes.Status401Unauthorized
            };
            return;
        }

        await next();
    }
}
