using System.Threading.RateLimiting;

namespace Api.Middleware;

/// <summary>
/// A high limit per address, checked before sign-in, that only stops floods such as fake tokens.
/// The everyday limits are per person, because a whole campus can share one address.
/// </summary>
public sealed class IpFloodGuardMiddleware : IDisposable
{
    private readonly RequestDelegate _next;
    private readonly PartitionedRateLimiter<string> _limiter;

    public IpFloodGuardMiddleware(RequestDelegate next, IConfiguration configuration)
    {
        _next = next;
        var limit = configuration.GetValue("RateLimiting:IpPermitLimit", 2000);
        _limiter = PartitionedRateLimiter.Create<string, string>(ip => RateLimitPartition.GetFixedWindowLimiter(ip,
            _ => new FixedWindowRateLimiterOptions { PermitLimit = limit, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
    }

    public async Task InvokeAsync(HttpContext context)
    {
        using var lease = _limiter.AttemptAcquire(context.Connection.RemoteIpAddress?.ToString() ?? "unknown_ip");
        if (!lease.IsAcquired)
        {
            context.Response.StatusCode = StatusCodes.Status429TooManyRequests;
            context.Response.Headers.RetryAfter = "60";
            await context.Response.WriteAsJsonAsync(new { message = "Too many requests. Try again later." });
            return;
        }

        await _next(context);
    }

    public void Dispose() => _limiter.Dispose();
}
