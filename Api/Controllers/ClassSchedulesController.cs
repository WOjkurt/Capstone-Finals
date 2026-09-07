using Api.Auth;
using Api.DTOs.Class;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ClassSchedulesController : ControllerBase
{
    private readonly IClassScheduleService _scheduleService;

    public ClassSchedulesController(IClassScheduleService scheduleService)
    {
        _scheduleService = scheduleService;
    }

    [HttpPut("{id:guid}")]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> Update(Guid id, [FromBody] CreateClassScheduleDto dto)
    {
        try
        {
            var schedule = await _scheduleService.UpdateAsync(id, dto);
            return Ok(schedule);
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

    [HttpDelete("{id:guid}")]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> Delete(Guid id)
    {
        try
        {
            await _scheduleService.DeleteAsync(id);
            return Ok(new { message = "Schedule deleted successfully." });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }
}
