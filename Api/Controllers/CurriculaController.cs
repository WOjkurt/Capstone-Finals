using Api.Auth;
using Api.Domain.Audit;
using Api.DTOs.Curriculum;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>Curriculum versions of each program, and which one a student follows.</summary>
[ApiController]
[Route("api/curricula")]
public class CurriculaController : ControllerBase
{
    private readonly ICurriculumService _service;

    public CurriculaController(ICurriculumService service)
    {
        _service = service;
    }

    [HttpGet]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> GetAll([FromQuery] int? programId) => Ok(await _service.GetAllAsync(programId));

    [HttpPost]
    [RequireRegistrarOrAdmin]
    public Task<IActionResult> Create([FromBody] SaveCurriculumDto dto) =>
        Run(async callerId =>
        {
            var c = await _service.CreateAsync(dto);
            await LogAsync(callerId, ActivityActions.SettingsChanged,
                $"Curriculum added: {c.ProgramCode} {c.Name} (from SY {c.EffectiveSchoolYear})", null);
            return Ok(c);
        });

    [HttpPut("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public Task<IActionResult> Update(Guid id, [FromBody] SaveCurriculumDto dto) =>
        Run(async callerId =>
        {
            var c = await _service.UpdateAsync(id, dto);
            await LogAsync(callerId, ActivityActions.SettingsChanged,
                $"Curriculum edited: {c.ProgramCode} {c.Name} (from SY {c.EffectiveSchoolYear})", null);
            return Ok(c);
        });

    [HttpDelete("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public Task<IActionResult> Delete(Guid id) =>
        Run(async callerId =>
        {
            await _service.DeleteAsync(id);
            await LogAsync(callerId, ActivityActions.SettingsChanged, "Curriculum deleted", null);
            return NoContent();
        });

    [HttpGet("student/{userId:guid}")]
    [RequireRegistrarCollegeHeadOrAdmin]
    public Task<IActionResult> GetStudentCurriculum(Guid userId) =>
        Run(async _ => Ok(await _service.GetStudentCurriculumAsync(userId)));

    [HttpPut("student/{userId:guid}")]
    [RequireRegistrarOrAdmin]
    public Task<IActionResult> SetStudentCurriculum(Guid userId, [FromBody] SetStudentCurriculumDto dto) =>
        Run(async callerId =>
        {
            var (oldName, newName) = await _service.SetStudentCurriculumAsync(userId, dto.CurriculumID);
            await LogAsync(callerId, ActivityActions.CurriculumChanged,
                $"Curriculum changed: {oldName ?? "none"} → {newName}", userId);
            return Ok(new { curriculumId = dto.CurriculumID, name = newName });
        });

    private async Task<IActionResult> Run(Func<Guid, Task<IActionResult>> action)
    {
        if (this.CallerId() is not { } callerId) return Unauthorized(new { message = "Authentication required." });
        try
        {
            return await action(callerId);
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
            return Conflict(new { message = ex.Message });
        }
    }

    private async Task LogAsync(Guid callerId, string action, string summary, Guid? studentId)
    {
        if (this.ActivityLog() is { } log) await log.LogAsync(callerId, action, summary, studentId);
    }
}
