using Api.Auth;
using Api.Data;
using Api.Domain.Enrollment;
using Api.Repositories;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MeController : ControllerBase
{
    private readonly IUserDetailsRepository _userDetails;
    private readonly AppDbContext _context;

    public MeController(IUserDetailsRepository userDetails, AppDbContext context)
    {
        _userDetails = userDetails;
        _context = context;
    }

    /// <summary>
    /// Why this term's grades are not showing, when they are not.
    ///
    /// Without this the student app can only render an empty list, which is indistinguishable
    /// from "no grades have been entered yet" -- so every withheld student reports a bug, and
    /// the office that could actually help them never hears about it. Returning the reason lets
    /// the app name the office to go and see.
    /// </summary>
    [HttpGet("grade-visibility")]
    [RequireStudent]
    public async Task<IActionResult> GetGradeVisibility()
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var idObj) || idObj is not Guid userId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var activeTerm = await _context.AcademicTerms.AsNoTracking().FirstOrDefaultAsync(t => t.IsActive);
        if (activeTerm == null)
        {
            return Ok(new { withheld = false, reason = (string?)null, message = (string?)null });
        }

        bool unpaid = await _context.EnrollmentHolds.AsNoTracking()
            .AnyAsync(h => h.UserID == userId
                        && h.Reason == EnrollmentHoldReasons.UnpaidBalance
                        && h.RemovedAt == null);
        if (unpaid)
        {
            return Ok(new
            {
                withheld = true,
                reason = EnrollmentHoldReasons.UnpaidBalance,
                message = "Your grades for this term are on hold pending clearance from the Accounting Office."
            });
        }

        bool cleared = await _context.GradeClearances.AsNoTracking()
            .AnyAsync(c => c.UserID == userId && c.TermID == activeTerm.TermID && c.IsCleared);
        if (!cleared)
        {
            return Ok(new
            {
                withheld = true,
                reason = "NotCleared",
                message = "Your grades for this term are withheld pending clearance. Please see the Registrar."
            });
        }

        return Ok(new { withheld = false, reason = (string?)null, message = (string?)null });
    }

    [HttpGet]
    public async Task<IActionResult> GetCurrentUserInfo()
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) ||
            !HttpContext.Items.TryGetValue("email", out var emailObj) ||
            !HttpContext.Items.TryGetValue("role", out var roleObj))
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var userId = userIdObj as Guid? ?? Guid.Empty;
        var email = emailObj as string ?? string.Empty;
        var role = roleObj as int? ?? 0;
        var firebaseUid = HttpContext.Items.TryGetValue("firebase_uid", out var uidObj) ? uidObj as string : null;

        // The apps show the person's name in their menu; null when no details are on file.
        var details = userId == Guid.Empty ? null : await _userDetails.GetByUserIdAsync(userId);
        var fullName = details == null ? null : $"{details.Firstname} {details.Lastname}".Trim();

        return Ok(new
        {
            userID = userId,
            email = email,
            fullName = string.IsNullOrEmpty(fullName) ? null : fullName,
            role = role,
            roleName = RoleUtils.GetRoleName(role),
            firebaseUID = firebaseUid
        });
    }
}
