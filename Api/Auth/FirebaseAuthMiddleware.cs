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

    /// <summary>Password failures stay with Firebase. These are real accounts the school refuses.</summary>
    private static Task RecordBlockedAsync(HttpContext context, string email, Guid? userId, string reason)
    {
        var events = context.RequestServices?.GetService<Api.Services.SecurityEventLog>();
        return events == null
            ? Task.CompletedTask
            : events.RecordAsync($"signin:{email}:{reason}", userId, Api.Domain.Audit.ActivityActions.SignInBlocked,
                $"Sign-in blocked for {email}: {reason}");
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
        string configuredDomain = SchoolEmailValidator.GetAllowedDomain(configuration);
        string emailDomain = SchoolEmailValidator.GetEmailDomain(email);

        if (!SchoolEmailValidator.IsValidDomain(email, configuredDomain))
        {
            await RecordBlockedAsync(context, email, null, "not a school email");
            _logger.LogWarning("Auth rejected: email domain not in allowed list. EmailDomain={EmailDomain}, AllowedDomain={AllowedDomain}", emailDomain, configuredDomain);
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new { error = "Only DBTC-Cebu school email addresses are allowed." });
            return;
        }

        // ── Email Verification Check (BEFORE user lookup / auto-create) ──
        bool emailVerified = false;
        if (decodedToken.Claims.TryGetValue("email_verified", out var rawVerifiedObj))
        {
            if (rawVerifiedObj is bool b)
            {
                emailVerified = b;
            }
            else if (rawVerifiedObj is string s && bool.TryParse(s, out var parsed))
            {
                emailVerified = parsed;
            }
            else if (rawVerifiedObj is System.Text.Json.JsonElement je &&
                     (je.ValueKind == System.Text.Json.JsonValueKind.True || je.ValueKind == System.Text.Json.JsonValueKind.False))
            {
                emailVerified = je.GetBoolean();
            }
        }

        bool requireVerifiedEmail = configuration.GetValue<bool?>("Auth:RequireVerifiedEmail") ?? true;
        if (requireVerifiedEmail && !emailVerified)
        {
            _logger.LogWarning("Auth rejected: email not verified for UID={Uid}", uid);
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new
            {
                error = "email_not_verified",
                message = "Please verify your email address, then sign in again."
            });
            return;
        }

        // ── Postgres User Lookup / Auto-Create ─────────────────────────
        var user = await db.Users
            .FirstOrDefaultAsync(u => u.FirebaseUID == uid);

        if (user == null)
        {
            // A student imported from the registrar's records has a pending account with their school email:
            // the first sign-in with that (verified) email makes it theirs.
            var loginEmail = email.ToLowerInvariant();
            var pending = await db.Users.FirstOrDefaultAsync(u =>
                u.FirebaseUID.StartsWith(Api.Services.RecordsImportService.PendingUidPrefix) &&
                u.Role == RoleUtils.Student && u.Email == loginEmail);
            if (pending != null)
            {
                pending.FirebaseUID = uid;
                await db.SaveChangesAsync();
                user = pending;
                _logger.LogInformation("Imported student signed in for the first time; pending account claimed. UserID={UserID}", user.UserID);
            }
        }

        if (user == null)
        {
            // Only auto-create a Users row if there is an approved EnrollmentApplication whose
            // SchoolEmail matches this login email (lowercase) and the account hasn't
            // been linked yet (StudentUserID == null). This prevents staff whose accounts haven't
            // been manually provisioned from being silently created as Students.
            var normalizedEmail = email.ToLowerInvariant();
            bool hasApprovedApplication = await db.EnrollmentApplications
                .AnyAsync(ea =>
                    ea.Status == 2 &&
                    ea.StudentUserID == null &&
                    ea.SchoolEmail != null &&
                    ea.SchoolEmail.ToLower() == normalizedEmail);

            if (!hasApprovedApplication)
            {
                // The token is valid (authenticated) but this email has no registered account.
                // Use 403 (not 401) so clients do NOT trigger a re-login loop on 401.
                // Generic message: we do not reveal whether an application exists.
                await RecordBlockedAsync(context, email, null, "no registered account");
                _logger.LogInformation("Auth denied: no registered account found for this email. Auto-creation skipped.");
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                context.Response.ContentType = "application/json";
                await context.Response.WriteAsJsonAsync(new
                {
                    error = "account_not_registered"
                });
                return;
            }

            user = new Api.Domain.IdentityAccess.User
            {
                UserID = Guid.NewGuid(),
                FirebaseUID = uid,
                Email = normalizedEmail,
                Role = RoleUtils.Student,
                CreatedAt = DateTime.UtcNow
            };
            db.Users.Add(user);
            await db.SaveChangesAsync();
            _logger.LogInformation("Auto-created new Users row for new student account (FirebaseUID length={UidLength}).", uid.Length);
        }

        if (!user.IsActive)
        {
            await RecordBlockedAsync(context, email, user.UserID, "account is disabled");
            _logger.LogWarning("Auth denied: account is disabled. UserID={UserID}", user.UserID);
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new
            {
                error = "account_inactive",
                message = "This account has been disabled. Please contact an administrator."
            });
            return;
        }

        if (!RoleUtils.IsValidRole(user.Role))
        {
            _logger.LogError("Invalid or missing role for user. UserID={UserID}, Role={Role}", user.UserID, user.Role);
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new
            {
                error = "account_inactive"
            });
            return;
        }

        context.Items["firebase_uid"] = uid;
        context.Items["email"] = email;
        context.Items["role"] = user.Role;
        context.Items["user_id"] = user.UserID;

        await _next(context);
    }
}
