using Api.Auth;
using Api.Common;
using Api.Domain.Audit;
using Api.DTOs.Setup;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AcademicTermsController : ControllerBase
{
    private readonly IAcademicTermService _termService;

    public AcademicTermsController(IAcademicTermService termService)
    {
        _termService = termService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var terms = await _termService.GetAllAsync();
        return Ok(terms);
    }

    [HttpGet("active")]
    public async Task<IActionResult> GetActive()
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var term = await _termService.GetActiveAsync();
        if (term == null)
        {
            return NotFound(new { message = "No active academic term found." });
        }

        return Ok(term);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var term = await _termService.GetByIdAsync(id);
        if (term == null)
        {
            return NotFound(new { message = $"AcademicTerm with ID '{id}' was not found." });
        }

        return Ok(term);
    }

    [HttpPost]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Create([FromBody] CreateAcademicTermDto dto)
    {
        try
        {
            var term = await _termService.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = term.TermID }, term);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Update(Guid id, [FromBody] CreateAcademicTermDto dto)
    {
        try
        {
            var term = await _termService.UpdateAsync(id, dto);
            return Ok(term);
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

    [HttpPatch("{id:guid}/activate")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Activate(Guid id)
    {
        try
        {
            var term = await _termService.ActivateAsync(id);
            return Ok(term);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    /// <summary>Sets the days old students can enroll online for this term; both empty closes it.</summary>
    [HttpPatch("{id:guid}/enrollment-period")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> SetEnrollmentPeriod(Guid id, [FromBody] SetEnrollmentPeriodDto dto)
    {
        try
        {
            var term = await _termService.SetEnrollmentPeriodAsync(id, dto);
            var log = this.ActivityLog();
            if (log != null)
            {
                var label = TermLabel.Format(term.SchoolYear, term.Semester);
                await log.LogAsync(this.CallerId(), ActivityActions.SettingsChanged,
                    term.EnrollmentOpensOn is { } opens && term.EnrollmentClosesOn is { } closes
                        ? $"Online enrollment for {label} set to {opens:MMM d, yyyy} - {closes:MMM d, yyyy}"
                        : $"Online enrollment for {label} closed (dates cleared)",
                    termId: term.TermID);
            }
            return Ok(term);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpDelete("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Delete(Guid id)
    {
        try
        {
            await _termService.DeleteAsync(id);
            return Ok(new { message = "AcademicTerm deleted successfully." });
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
}
