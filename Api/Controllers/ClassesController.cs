using Api.Auth;
using Api.DTOs.Class;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ClassesController : ControllerBase
{
    private readonly IClassService _classService;
    private readonly IClassScheduleService _scheduleService;

    public ClassesController(IClassService classService, IClassScheduleService scheduleService)
    {
        _classService = classService;
        _scheduleService = scheduleService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] Guid? termId, [FromQuery] Guid? subjectId, [FromQuery] Guid? teacherUserId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var classes = await _classService.GetAllAsync(termId, subjectId, teacherUserId);
        return Ok(classes);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var classDto = await _classService.GetByIdAsync(id);
        if (classDto == null)
        {
            return NotFound(new { message = $"Class with ID '{id}' was not found." });
        }

        return Ok(classDto);
    }

    [HttpPost]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> Create([FromBody] CreateClassDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid createdByUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var classDto = await _classService.CreateAsync(dto, createdByUserId);
            return CreatedAtAction(nameof(GetById), new { id = classDto.ClassID }, classDto);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpPut("{id:guid}")]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateClassDto dto)
    {
        try
        {
            var classDto = await _classService.UpdateAsync(id, dto);
            return Ok(classDto);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpDelete("{id:guid}")]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> Delete(Guid id)
    {
        try
        {
            await _classService.DeleteAsync(id);
            return Ok(new { message = "Class deleted successfully." });
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

    // ── Nested schedule endpoints under /api/Classes/{classId}/schedules ──

    [HttpGet("{classId:guid}/schedules")]
    public async Task<IActionResult> GetSchedules(Guid classId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var schedules = await _scheduleService.GetByClassIdAsync(classId);
        return Ok(schedules);
    }

    [HttpPost("{classId:guid}/schedules")]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> CreateSchedule(Guid classId, [FromBody] CreateClassScheduleDto dto)
    {
        dto.ClassID = classId;
        try
        {
            var schedule = await _scheduleService.CreateAsync(dto);
            return CreatedAtAction(nameof(GetSchedules), new { classId = classId }, schedule);
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
