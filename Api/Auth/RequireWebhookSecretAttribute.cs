using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Api.Auth;

/// <summary>
/// Accepts a webhook call only from someone who knows the shared secret, before its body is used.
/// Signed call: X-Webhook-Timestamp (Unix seconds) and X-Webhook-Signature =
/// "sha256=" + hex HMAC-SHA256(secret, timestamp + "." + body). The secret never travels, and a
/// copied call stops working after five minutes.
/// Plain call: the secret itself in X-Webhook-Secret, accepted while Webhook:AllowPlainSecret is true.
/// </summary>
[AttributeUsage(AttributeTargets.Method)]
public class RequireWebhookSecretAttribute : Attribute, IAsyncResourceFilter
{
    public const string TimestampHeader = "X-Webhook-Timestamp";
    public const string SignatureHeader = "X-Webhook-Signature";
    public const string SecretHeader = "X-Webhook-Secret";
    public static readonly TimeSpan MaxAge = TimeSpan.FromMinutes(5);

    public async Task OnResourceExecutionAsync(ResourceExecutingContext context, ResourceExecutionDelegate next)
    {
        var http = context.HttpContext;
        var config = http.RequestServices.GetRequiredService<IConfiguration>();
        string? secret = config["Webhook:GoogleFormsSecret"];
        string? signature = http.Request.Headers[SignatureHeader].FirstOrDefault();

        bool trusted = !string.IsNullOrEmpty(secret) && (signature != null
            ? await SignatureMatchesAsync(http, secret, signature)
            : config.GetValue("Webhook:AllowPlainSecret", true) &&
              Same(http.Request.Headers[SecretHeader].FirstOrDefault(), secret));

        if (!trusted)
        {
            context.Result = new UnauthorizedObjectResult(new { message = "Invalid or missing webhook secret." });
            return;
        }

        await next();
    }

    private static async Task<bool> SignatureMatchesAsync(HttpContext http, string secret, string signature)
    {
        string? timestamp = http.Request.Headers[TimestampHeader].FirstOrDefault();
        if (!long.TryParse(timestamp, NumberStyles.None, CultureInfo.InvariantCulture, out long seconds)) return false;

        var now = (http.RequestServices.GetService<TimeProvider>() ?? TimeProvider.System).GetUtcNow();
        var sentAt = DateTimeOffset.FromUnixTimeSeconds(Math.Min(seconds, 253402300799));
        if ((now - sentAt).Duration() > MaxAge) return false;

        // Read the body as sent, then rewind it for the controller.
        http.Request.EnableBuffering();
        using var body = new MemoryStream();
        await http.Request.Body.CopyToAsync(body, http.RequestAborted);
        http.Request.Body.Position = 0;

        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        hmac.TransformBlock(Encoding.UTF8.GetBytes(timestamp + "."), 0, timestamp!.Length + 1, null, 0);
        hmac.TransformFinalBlock(body.GetBuffer(), 0, (int)body.Length);
        string expected = "sha256=" + Convert.ToHexStringLower(hmac.Hash!);

        return Same(signature.Trim().ToLowerInvariant(), expected);
    }

    private static bool Same(string? sent, string expected) =>
        !string.IsNullOrEmpty(sent) &&
        CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(sent), Encoding.UTF8.GetBytes(expected));
}
