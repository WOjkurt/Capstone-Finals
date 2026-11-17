using Api.Auth;
using Api.Domain.Audit;
using Api.DTOs.Grading;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

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
    [RequireTeacher]
    public async Task<IActionResult> SubmitGrade([FromBody] SubmitGradeDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var result = await _gradeService.SubmitGradeAsync(dto, authenticatedUserId);

            var log = this.ActivityLog();
            if (log != null)
            {
                await log.LogAsync(authenticatedUserId, ActivityActions.GradeSubmitted,
                    $"{result.SubjectCode ?? "?"} ({result.ClassName ?? "?"}): "
                        + $"{DescribeGrades(result.MidtermGrade, result.FinalGrade)}",
                    result.StudentUserId, result.TermId);
            }

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

    [HttpPost("submit-batch")]
    [RequireTeacher]
    public async Task<IActionResult> SubmitGradeBatch([FromBody] SubmitGradeBatchDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var result = await _gradeService.SubmitGradeBatchAsync(dto, authenticatedUserId);

            var log = this.ActivityLog();
            if (log != null)
            {
                // One entry per student, so a disputed grade can be traced to
                // the person who entered it and when.
                foreach (var g in result.Succeeded)
                {
                    await log.LogAsync(authenticatedUserId, ActivityActions.GradeSubmitted,
                        $"{g.SubjectCode ?? "?"} ({g.ClassName ?? "?"}): "
                            + $"{DescribeGrades(g.MidtermGrade, g.FinalGrade)}",
                        g.StudentUserId, g.TermId);
                }
            }

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
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>"midterm 1.75, final 2.00" — only the periods that carry a grade.</summary>
    private static string DescribeGrades(decimal? midterm, decimal? final)
    {
        var parts = new List<string>();
        if (midterm.HasValue) parts.Add($"midterm {midterm.Value:0.00}");
        if (final.HasValue) parts.Add($"final {final.Value:0.00}");
        return parts.Count == 0 ? "no grade" : string.Join(", ", parts);
    }

    [HttpGet("studyload/{studyLoadId:guid}")]
    public async Task<IActionResult> GetByStudyLoad(Guid studyLoadId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId || authenticatedUserId == Guid.Empty ||
            !HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int authenticatedUserRole)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var grade = await _gradeService.GetByStudyLoadIdAsync(studyLoadId, authenticatedUserId, authenticatedUserRole);
            if (grade == null)
            {
                return NotFound(new { message = $"Grade for StudyLoad ID '{studyLoadId}' was not found." });
            }

            return Ok(grade);
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
    }


    [HttpGet("class/{classId:guid}")]
    [EnableRateLimiting("search")]
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
    [EnableRateLimiting("search")]
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
