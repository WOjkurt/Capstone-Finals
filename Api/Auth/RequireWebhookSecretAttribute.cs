using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Api.Auth;

/// <summary>Rejects a webhook call without the shared secret, before its body is looked at.</summary>
[AttributeUsage(AttributeTargets.Method)]
public class RequireWebhookSecretAttribute : Attribute, IAsyncActionFilter, IOrderedFilter
{
    public int Order => AuthFilterOrder.RoleCheck;

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var http = context.HttpContext;
        string? sent = http.Request.Headers["X-Webhook-Secret"].FirstOrDefault();
        string? expected = http.RequestServices.GetRequiredService<IConfiguration>()["Webhook:GoogleFormsSecret"];

        if (string.IsNullOrEmpty(expected) || string.IsNullOrEmpty(sent) ||
            !CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(sent), Encoding.UTF8.GetBytes(expected)))
        {
            context.Result = new UnauthorizedObjectResult(new { message = "Invalid or missing webhook secret." });
            return;
        }

        await next();
    }
}
