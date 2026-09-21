using FirebaseAdmin.Auth;
using Microsoft.EntityFrameworkCore;

namespace Api.Auth;

public class FirebaseAuthMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<FirebaseAuthMiddleware> _logger;
    private readonly IFirebaseAuthVerifier _verifier;

    public FirebaseAuthMiddleware(
        RequestDelegate next,
        ILogger<FirebaseAuthMiddleware> logger,
        IFirebaseAuthVerifier verifier)
    {
        _next = next;
        _logger = logger;
        _verifier = verifier;
    }

    public async Task InvokeAsync(HttpContext context, AppDbContext db, IConfiguration configuration)
    {
        string? authHeader = context.Request.Headers["Authorization"].FirstOrDefault();

        if (string.IsNullOrWhiteSpace(authHeader) || !authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            await _next(context);
            return;
        }

        string token = authHeader["Bearer ".Length..].Trim();
        if (string.IsNullOrEmpty(token))
        {
            await _next(context);
            return;
        }

        // ── Firebase instance null-guard ─────────────────────────────────────
        if (!_verifier.IsInitialized)
        {
            _logger.LogCritical("Firebase is not initialized — check FIREBASE_KEY_PATH and service account configuration. All authenticated requests will fail.");
            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            await context.Response.WriteAsJsonAsync(new { message = "Authentication service unavailable." });
            return;
        }

        FirebaseToken decodedToken;
        try
        {
            decodedToken = await _verifier.VerifyIdTokenAsync(token, checkRevoked: true);
        }
        catch (TokenVerificationException ex)
        {
            _logger.LogWarning("Token verification failed: {AuthErrorCode} — {Message}", ex.AuthErrorCode, ex.Message);
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            context.Response.ContentType = "application/json";
            var isExpiredOrRevoked = ex.AuthErrorCode is AuthErrorCode.ExpiredIdToken or AuthErrorCode.RevokedIdToken;
            await context.Response.WriteAsJsonAsync(new
            {
                error = isExpiredOrRevoked ? "token_expired" : "invalid_token"
            });
            return;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during token verification");
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new
            {
                error = "invalid_token"
            });
            return;
        }

        string uid = decodedToken.Uid;
        string email = decodedToken.Claims.TryGetValue("email", out var rawEmailObj) ? rawEmailObj?.ToString() ?? string.Empty : string.Empty;

        // ── Domain Validation (Executed BEFORE DB lookup) ────────────────
        string allowedDomain = configuration["Auth:AllowedEmailDomain"] ?? "@dbtc-cebu.edu.ph";
        if (string.IsNullOrWhiteSpace(email) || !email.EndsWith(allowedDomain, StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("Auth rejected: email domain not in allowed list. AllowedDomain={AllowedDomain}", allowedDomain);
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new { error = "Only DBTC-Cebu school email addresses are allowed." });
            return;
        }

        // ── Postgres User Lookup / Auto-Create ─────────────────────────
        var user = await db.Users
            .FirstOrDefaultAsync(u => u.FirebaseUID == uid);

        if (user == null)
        {
            // Only auto-create a Users row if there is an approved EnrollmentApplication whose
            // linked EnrollmentResponse email matches this login email and the account hasn't
            // been linked yet (StudentUserID == null). This prevents staff whose accounts haven't
            // been manually provisioned from being silently created as Students.
            bool hasApprovedApplication = await db.EnrollmentApplications
                .Join(db.EnrollmentResponses,
                    ea => ea.ResponseID,
                    er => er.ResponseID,
                    (ea, er) => new { ea, er })
                .AnyAsync(x =>
                    x.ea.Status == 2 &&
                    x.ea.StudentUserID == null &&
                    x.er.EmailAddress.ToLower() == email.ToLower());

            if (!hasApprovedApplication)
            {
                _logger.LogInformation("Auth denied: no approved application found for this email. Auto-creation skipped.");
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                context.Response.ContentType = "application/json";
                await context.Response.WriteAsJsonAsync(new
                {
                    error = "No account found for this email. If you are a student, ensure your enrollment application has been approved. If you are staff, contact your administrator."
                });
                return;
            }

            user = new Api.Domain.IdentityAccess.User
            {
                UserID = Guid.NewGuid(),
                FirebaseUID = uid,
                Email = email,
                Role = RoleUtils.Student,
                CreatedAt = DateTime.UtcNow
            };
            db.Users.Add(user);
            await db.SaveChangesAsync();
            _logger.LogInformation("Auto-created new Users row for new student account (FirebaseUID length={UidLength}).", uid.Length);
        }

        if (!user.IsActive)
        {
            _logger.LogWarning("Auth denied: account is disabled. UserID={UserID}", user.UserID);
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new
            {
                message = "This account has been disabled. Please contact an administrator."
            });
            return;
        }

        if (!RoleUtils.IsValidRole(user.Role))
        {
            _logger.LogError("Invalid or missing role for user. UserID={UserID}, Role={Role}", user.UserID, user.Role);
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return;
        }

        context.Items["firebase_uid"] = uid;
        context.Items["email"] = email;
        context.Items["role"] = user.Role;
        context.Items["user_id"] = user.UserID;

        await _next(context);
    }
}
