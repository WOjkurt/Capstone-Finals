using Api.Auth;
using Api.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MeController : ControllerBase
{
    private readonly IUserDetailsRepository _userDetails;

    public MeController(IUserDetailsRepository userDetails)
    {
        _userDetails = userDetails;
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
