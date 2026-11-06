using Api.Auth;
using Api.Domain.Audit;
using Api.DTOs.Setup;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>School-wide settings (Setup → Unit Limits).</summary>
[ApiController]
[Route("api/school-settings")]
public class SchoolSettingsController : ControllerBase
{
    private readonly ISchoolSettingsService _settings;

    public SchoolSettingsController(ISchoolSettingsService settings)
    {
        _settings = settings;
    }

    [HttpGet("unit-limits")]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> GetUnitLimits() => Ok(await _settings.GetUnitLimitsAsync());

    [HttpPut("unit-limits")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> SaveUnitLimits([FromBody] SaveUnitLimitSettingsDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid callerId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }
        try
        {
            var before = await _settings.GetUnitLimitsAsync();
            var saved = await _settings.SaveUnitLimitsAsync(dto, callerId);
            var log = this.ActivityLog();
            if (log != null)
            {
                await log.LogAsync(callerId, ActivityActions.SettingsChanged,
                    $"Summer unit limits: {before.SummerMaxUnits:0.#} -> {saved.SummerMaxUnits:0.#}, graduating {before.GraduatingSummerMaxUnits:0.#} -> {saved.GraduatingSummerMaxUnits:0.#}");
            }
            return Ok(saved);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
