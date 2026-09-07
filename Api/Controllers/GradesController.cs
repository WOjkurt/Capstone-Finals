using Api.DTOs.Grading;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/grades")]
public class GradesController : ControllerBase
{
    private readonly IGradeService _gradeService;

    public GradesController(IGradeService gradeService)
    {
        _gradeService = gradeService;
    }

    [HttpPost("submit")]
    public async Task<IActionResult> SubmitGrade([FromBody] SubmitGradeDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var result = await _gradeService.SubmitGradeAsync(dto, authenticatedUserId);
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("studyload/{studyLoadId:guid}")]
    public async Task<IActionResult> GetByStudyLoad(Guid studyLoadId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var grade = await _gradeService.GetByStudyLoadIdAsync(studyLoadId);
        if (grade == null)
        {
            return NotFound(new { message = $"Grade for StudyLoad ID '{studyLoadId}' was not found." });
        }

        return Ok(grade);
    }

    [HttpGet("class/{classId:guid}")]
    public async Task<IActionResult> GetByClass(Guid classId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId ||
            !HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int authenticatedUserRole)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var grades = await _gradeService.GetByClassIdAsync(classId, authenticatedUserId, authenticatedUserRole);
            return Ok(grades);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
    }

    [HttpGet("student/{userId:guid}")]
    public async Task<IActionResult> GetByStudent(Guid userId, [FromQuery] Guid? termId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId ||
            !HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int authenticatedUserRole)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var grades = await _gradeService.GetByStudentIdAsync(userId, termId, authenticatedUserId, authenticatedUserRole);
            return Ok(grades);
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
    }
}
