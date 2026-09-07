using Api.Auth;
using Api.DTOs.Grading;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/gradeclearances")]
public class GradeClearancesController : ControllerBase
{
    private readonly IGradeClearanceService _clearanceService;

    public GradeClearancesController(IGradeClearanceService clearanceService)
    {
        _clearanceService = clearanceService;
    }

    [HttpPatch("{userId:guid}/{termId:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> SetClearance(Guid userId, Guid termId, [FromBody] SetGradeClearanceDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid reviewerUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var result = await _clearanceService.SetClearanceAsync(userId, termId, dto.IsCleared, reviewerUserId);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("{userId:guid}")]
    public async Task<IActionResult> GetByStudent(Guid userId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId ||
            !HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int authenticatedUserRole)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        bool isSelf = authenticatedUserId == userId;
        bool isStaff = authenticatedUserRole == RoleUtils.Registrar ||
                       authenticatedUserRole == RoleUtils.Admin ||
                       authenticatedUserRole == RoleUtils.ProgramHead;

        if (!isSelf && !isStaff)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Access denied. You can only view your own grade clearances unless you are a Registrar, Admin, or Program Head." });
        }

        var clearances = await _clearanceService.GetByStudentAsync(userId);
        return Ok(clearances);
    }
}
