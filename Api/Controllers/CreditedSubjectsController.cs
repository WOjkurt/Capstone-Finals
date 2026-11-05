using Api.Auth;
using Api.Domain.Audit;
using Api.Domain.Enrollment;
using Api.DTOs.Credits;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>Subjects credited from another school (transferees, shiftees).</summary>
[ApiController]
[Route("api/credited-subjects")]
public class CreditedSubjectsController : ControllerBase
{
    private readonly ICreditedSubjectService _service;

    public CreditedSubjectsController(ICreditedSubjectService service)
    {
        _service = service;
    }

    [HttpGet("student/{userId:guid}")]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> GetByStudent(Guid userId)
    {
        return Ok(await _service.GetByStudentAsync(userId));
    }

    [HttpPost]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Create([FromBody] CreateCreditedSubjectDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid callerId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var credit = await _service.CreateAsync(dto, callerId);
            var log = this.ActivityLog();
            if (log != null)
            {
                await log.LogAsync(callerId, ActivityActions.CreditAdded,
                    $"Credited {credit.SubjectCode} ({credit.CreditedUnits:0.#} of {credit.Units:0.#} units) " +
                    (credit.Kind == CreditKinds.CrossEnrollment ? $"cross-enrolled at {credit.SourceSchool} in {credit.TermLabel}" : $"from {credit.SourceSchool}") +
                    (credit.Grade != null ? $" (grade {credit.Grade})" : ""),
                    credit.UserId);
            }
            return Ok(credit);
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

    [HttpDelete("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Delete(Guid id)
    {
        try
        {
            var log = this.ActivityLog();
            var credit = log != null ? await _service.GetByIdAsync(id) : null;
            await _service.DeleteAsync(id);
            if (log != null && credit != null)
            {
                await log.LogAsync(this.CallerId(), ActivityActions.CreditRemoved,
                    $"Removed credit for {credit.SubjectCode} from {credit.SourceSchool}", credit.UserId);
            }
            return NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }
}
