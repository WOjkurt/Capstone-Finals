using FirebaseAdmin.Auth;
using Microsoft.EntityFrameworkCore;

namespace Api.Auth;

public class FirebaseAuthMiddleware
{
    private readonly RequestDelegate _next;

    public FirebaseAuthMiddleware(RequestDelegate next)
    {
        _next = next;
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

        FirebaseToken decodedToken;
        try
        {
            decodedToken = await FirebaseAuth.DefaultInstance.VerifyIdTokenAsync(token, checkRevoked: true);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[AUTH DEBUG] Token verification failed: {ex.Message}");
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return;
        }

        string uid = decodedToken.Uid;
        string email = decodedToken.Claims.TryGetValue("email", out var rawEmailObj) ? rawEmailObj?.ToString() ?? string.Empty : string.Empty;

        // ── Domain Validation (Executed BEFORE DB lookup) ────────────────
        string allowedDomain = configuration["Auth:AllowedEmailDomain"] ?? "@dbtc-cebu.edu.ph";
        if (string.IsNullOrWhiteSpace(email) || !email.EndsWith(allowedDomain, StringComparison.OrdinalIgnoreCase))
        {
            Console.WriteLine($"[AUTH DEBUG] Rejected email '{email}'. Does not match allowed domain '{allowedDomain}'.");
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
                Console.WriteLine($"[AUTH] No approved application found for new email '{email}'. Auto-creation denied.");
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
            Console.WriteLine($"[AUTH] Auto-created new Users row for FirebaseUID: {uid} with Email: {email}");
        }

        if (!user.IsActive)
        {
            Console.WriteLine($"[AUTH] Account '{email}' (uid: {uid}) is disabled.");
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
            Console.WriteLine($"[AUTH DEBUG] Invalid or missing role for uid: {uid}");
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
