using Api.Auth;
using Api.DTOs.Setup;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SubjectsController : ControllerBase
{
    private readonly ISubjectService _subjectService;

    public SubjectsController(ISubjectService subjectService)
    {
        _subjectService = subjectService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] int? programId, [FromQuery] int? yearLevel)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var subjects = await _subjectService.GetAllAsync(programId, yearLevel);
        return Ok(subjects);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var subject = await _subjectService.GetByIdAsync(id);
        if (subject == null)
        {
            return NotFound(new { message = $"Subject with ID '{id}' was not found." });
        }

        return Ok(subject);
    }

    [HttpPost]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Create([FromBody] CreateSubjectDto dto)
    {
        try
        {
            var subject = await _subjectService.CreateAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = subject.SubjectID }, subject);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpPut("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Update(Guid id, [FromBody] CreateSubjectDto dto)
    {
        try
        {
            var subject = await _subjectService.UpdateAsync(id, dto);
            return Ok(subject);
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
            await _subjectService.DeleteAsync(id);
            return Ok(new { message = "Subject deleted successfully." });
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

    [HttpGet("{id:guid}/prerequisites")]
    public async Task<IActionResult> GetPrerequisites(Guid id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var prereqs = await _subjectService.GetPrerequisitesForSubjectAsync(id);
            return Ok(prereqs);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpPost("{id:guid}/prerequisites")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> AddPrerequisite(Guid id, [FromBody] CreatePrerequisiteDto dto)
    {
        dto.SubjectID = id;
        try
        {
            var prereq = await _subjectService.AddPrerequisiteAsync(dto);
            return CreatedAtAction(nameof(GetPrerequisites), new { id = id }, prereq);
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

    [HttpDelete("prerequisites/{prerequisiteId:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> RemovePrerequisite(Guid prerequisiteId)
    {
        try
        {
            await _subjectService.RemovePrerequisiteAsync(prerequisiteId);
            return Ok(new { message = "Prerequisite relationship removed successfully." });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }
}
