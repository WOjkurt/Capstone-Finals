using Api.Auth;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MeController : ControllerBase
{
    [HttpGet]
    public IActionResult GetCurrentUserInfo()
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

        return Ok(new
        {
            userID = userId,
            email = email,
            role = role,
            roleName = RoleUtils.GetRoleName(role),
            firebaseUID = firebaseUid
        });
    }
}
