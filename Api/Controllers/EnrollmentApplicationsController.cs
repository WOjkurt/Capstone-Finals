using Api.Auth;
using Api.Domain.Enrollment;
using Api.DTOs.Enrollment;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[RequireRegistrarOrAdmin]
public class EnrollmentApplicationsController : ControllerBase
{
    private readonly IEnrollmentService _enrollmentService;

    public EnrollmentApplicationsController(IEnrollmentService enrollmentService)
    {
        _enrollmentService = enrollmentService;
    }

    [HttpPost]
    public async Task<IActionResult> CreateApplication([FromBody] CreateEnrollmentApplicationDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid createdByUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var applicationId = await _enrollmentService.CreateApplicationAsync(dto, createdByUserId);
            return CreatedAtAction(nameof(GetApplicationById), new { id = applicationId }, new { applicationID = applicationId });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPatch("{id:guid}/approve")]
    public async Task<IActionResult> ApproveApplication(Guid id, [FromBody] ApproveApplicationDto? dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid reviewedByUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            await _enrollmentService.ApproveApplicationAsync(id, reviewedByUserId, dto?.YearLevel);
            return Ok(new { message = "Application approved successfully." });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPatch("{id:guid}/reject")]
    public async Task<IActionResult> RejectApplication(Guid id, [FromBody] RejectApplicationDto? dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid reviewedByUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            await _enrollmentService.RejectApplicationAsync(id, reviewedByUserId, dto?.Reason);
            return Ok(new { message = "Application rejected successfully." });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPatch("{id:guid}/link-account")]
    public async Task<IActionResult> LinkAccount(Guid id, [FromBody] LinkAccountDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid reviewedByUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (string.IsNullOrWhiteSpace(dto.Email))
        {
            return BadRequest(new { message = "Email is required to link an account." });
        }

        try
        {
            var result = await _enrollmentService.LinkAccountAsync(id, dto.Email.Trim(), reviewedByUserId);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("approved")]
    public async Task<IActionResult> GetApprovedApplications()
    {
        var applications = await _enrollmentService.GetApprovedApplicationsAsync();
        return Ok(applications);
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? status)
    {
        if (!string.IsNullOrWhiteSpace(status))
        {
            if (!EnrollmentApplicationStatus.TryParse(status, out int parsedStatus))
            {
                return BadRequest(new
                {
                    message = "Invalid status filter. Allowed values: pending (1), approved (2), rejected (3), active (4)."
                });
            }

            var filtered = await _enrollmentService.GetApplicationsAsync(parsedStatus);
            return Ok(filtered);
        }

        var all = await _enrollmentService.GetApplicationsAsync(null);
        return Ok(all);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetApplicationById(Guid id)
    {
        var application = await _enrollmentService.GetApplicationByIdAsync(id);
        if (application == null)
        {
            return NotFound(new { message = "Enrollment application not found." });
        }

        return Ok(application);
    }

    [HttpPatch("{id:guid}/lrn")]
    public async Task<IActionResult> UpdateLrn(Guid id, [FromBody] UpdateApplicationLrnDto dto)
    {
        try
        {
            var result = await _enrollmentService.UpdateApplicationLrnAsync(id, dto.Lrn);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPatch("{id:guid}/school-email")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> UpdateSchoolEmail(Guid id, [FromBody] UpdateSchoolEmailDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid callerUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var result = await _enrollmentService.UpdateSchoolEmailAsync(id, dto?.SchoolEmail, callerUserId);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (DuplicateSchoolEmailException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}