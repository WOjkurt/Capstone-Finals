using Api.Auth;
using Api.DTOs.Class;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ClassSchedulesController : ControllerBase
{
    private readonly IClassScheduleService _scheduleService;
    private readonly IClassScheduleRepository _scheduleRepository;
    private readonly IClassRepository _classRepository;
    private readonly IProgramScopingService _scopingService;

    public ClassSchedulesController(
        IClassScheduleService scheduleService,
        IClassScheduleRepository scheduleRepository,
        IClassRepository classRepository,
        IProgramScopingService scopingService)
    {
        _scheduleService = scheduleService;
        _scheduleRepository = scheduleRepository;
        _classRepository = classRepository;
        _scopingService = scopingService;
    }

    [HttpPut("{id:guid}")]
    [RequireProgramHeadCollegeHeadOrAdmin]
    public async Task<IActionResult> Update(Guid id, [FromBody] CreateClassScheduleDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role && role == RoleUtils.ProgramHead)
        {
            var existingSchedule = await _scheduleRepository.GetByIdAsync(id);
            if (existingSchedule == null)
            {
                return NotFound(new { message = $"ClassSchedule with ID '{id}' was not found." });
            }

            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(authUserId, existingSchedule.Class?.Subject?.ProgramID, "schedule");

                if (existingSchedule.Class?.Subject?.IsMinor == true)
                {
                    return StatusCode(StatusCodes.Status403Forbidden, new { message = $"{existingSchedule.Class.Subject.SubjectCode} is a minor subject. Its schedule is set by the College Head." });
                }

                if (dto.ClassID != Guid.Empty && dto.ClassID != existingSchedule.ClassID)
                {
                    var targetClass = await _classRepository.GetByIdAsync(dto.ClassID);
                    if (targetClass == null)
                    {
                        return NotFound(new { message = $"Class with ID '{dto.ClassID}' was not found." });
                    }

                    await _scopingService.EnsureProgramHeadAccessAsync(authUserId, targetClass.Subject?.ProgramID, "class");

                    if (targetClass.Subject?.IsMinor == true)
                    {
                        return StatusCode(StatusCodes.Status403Forbidden, new { message = $"{targetClass.Subject.SubjectCode} is a minor subject. Its schedule is set by the College Head." });
                    }
                }
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

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
    [RequireProgramHeadCollegeHeadOrAdmin]
    public async Task<IActionResult> Delete(Guid id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role && role == RoleUtils.ProgramHead)
        {
            var existingSchedule = await _scheduleRepository.GetByIdAsync(id);
            if (existingSchedule == null)
            {
                return NotFound(new { message = $"ClassSchedule with ID '{id}' was not found." });
            }

            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(authUserId, existingSchedule.Class?.Subject?.ProgramID, "schedule");
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }

            if (existingSchedule.Class?.Subject?.IsMinor == true)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = $"{existingSchedule.Class.Subject.SubjectCode} is a minor subject. Its schedule is set by the College Head." });
            }
        }

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
