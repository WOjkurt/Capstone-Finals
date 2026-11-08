using Api.Auth;
using Api.Domain.Audit;
using Api.Domain.Enrollment;
using Api.DTOs.Holds;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>Holds that stop a student from enrolling online, such as an unpaid balance.</summary>
[ApiController]
[Route("api/enrollment-holds")]
public class EnrollmentHoldsController : ControllerBase
{
    private readonly IEnrollmentHoldService _service;

    public EnrollmentHoldsController(IEnrollmentHoldService service)
    {
        _service = service;
    }

    [HttpGet("student/{userId:guid}")]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> GetByStudent(Guid userId) => Ok(await _service.GetByStudentAsync(userId));

    [HttpPost("student/{userId:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Add(Guid userId, [FromBody] AddEnrollmentHoldDto dto)
    {
        if (this.CallerId() is not { } callerId) return Unauthorized(new { message = "Authentication required." });
        try
        {
            var hold = await _service.AddAsync(userId, dto, callerId);
            if (this.ActivityLog() is { } log)
            {
                await log.LogAsync(callerId, ActivityActions.HoldAdded,
                    $"Enrollment hold added: {hold.ReasonLabel}" + (hold.Note != null ? $" ({hold.Note})" : ""), userId);
            }
            return Ok(hold);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPatch("{id:guid}/remove")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Remove(Guid id, [FromBody] RemoveEnrollmentHoldDto dto)
    {
        if (this.CallerId() is not { } callerId) return Unauthorized(new { message = "Authentication required." });
        try
        {
            var hold = await _service.RemoveAsync(id, dto, callerId);
            if (this.ActivityLog() is { } log)
            {
                await log.LogAsync(callerId, ActivityActions.HoldRemoved,
                    $"Enrollment hold removed: {hold.ReasonLabel}" + (hold.RemovalNote != null ? $" ({hold.RemovalNote})" : ""),
                    hold.UserId);
            }
            return Ok(hold);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }
}
