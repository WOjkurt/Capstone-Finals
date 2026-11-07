using Api.Auth;
using Api.Domain.Audit;
using Api.Services;

namespace Api.Middleware;

/// <summary>Records signed-in people who ask for something their role does not allow.</summary>
public class DeniedRequestLogMiddleware
{
    private readonly RequestDelegate _next;

    public DeniedRequestLogMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context, SecurityEventLog events)
    {
        await _next(context);

        if (context.Response.StatusCode != StatusCodes.Status403Forbidden) return;
        if (!context.Items.TryGetValue("user_id", out var idObj) || idObj is not Guid userId) return;

        var role = context.Items.TryGetValue("role", out var roleObj) && roleObj is int r ? RoleUtils.GetRoleName(r) : "User";
        var request = $"{context.Request.Method} {context.Request.Path}";
        await events.RecordAsync($"denied:{userId}:{request}", userId, ActivityActions.AccessDenied,
            $"{role} was refused access to {request}");
    }
}
