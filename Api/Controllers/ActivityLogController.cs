using Api.Auth;
using Api.Domain.Audit;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>Read the staff activity log, newest first. Dates are UTC; <c>to</c> is exclusive.</summary>
[ApiController]
[Route("api/activity-log")]
[RequireRegistrarOrAdmin]
public class ActivityLogController : ControllerBase
{
    private readonly IActivityLogService _log;

    public ActivityLogController(IActivityLogService log)
    {
        _log = log;
    }

    [HttpGet]
    public async Task<IActionResult> Search(
        [FromQuery] DateTime? from, [FromQuery] DateTime? to, [FromQuery] string? action,
        [FromQuery] Guid? studentId, [FromQuery] Guid? actorId,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        if (!string.IsNullOrWhiteSpace(action) && !ActivityActions.All.Contains(action))
        {
            return BadRequest(new { message = $"Unknown action '{action}'." });
        }
        return Ok(await _log.SearchAsync(from, to, action, studentId, actorId, page, pageSize));
    }
}
