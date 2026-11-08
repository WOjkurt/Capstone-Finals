using Api.Auth;
using Api.Common;
using Api.Domain.Audit;
using Api.DTOs.Reenrollment;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Api.Controllers;

/// <summary>
/// An old student enrolling again from the Student Portal. The student is always the one signed in:
/// there is no student id in the address or the body to swap.
/// </summary>
[ApiController]
[Route("api/me/reenrollment")]
[RequireStudent]
public class ReenrollmentController : ControllerBase
{
    private readonly IReenrollmentService _service;

    public ReenrollmentController(IReenrollmentService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<IActionResult> GetStatus()
    {
        if (this.CallerId() is not { } studentId) return Unauthorized(new { message = "Authentication required." });
        return Ok(await _service.GetStatusAsync(studentId, SchoolClock.Today()));
    }

    [HttpPost]
    [EnableRateLimiting("reenroll")]
    public async Task<IActionResult> Submit([FromBody] SubmitReenrollmentDto dto)
    {
        if (this.CallerId() is not { } studentId) return Unauthorized(new { message = "Authentication required." });
        try
        {
            var (applicationId, termLabel, changed) = await _service.SubmitAsync(studentId, dto, SchoolClock.Today());
            if (this.ActivityLog() is { } log)
            {
                await log.LogAsync(studentId, ActivityActions.ReenrollmentSubmitted,
                    $"Enrolled online for {termLabel}" +
                    (changed.Count == 0 ? " (no changes)" : $"; changed: {string.Join(", ", changed)}"),
                    studentId, dto.TermId);
            }
            return Ok(new { applicationId, message = $"Your enrollment for {termLabel} was sent to the Registrar." });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }
}
