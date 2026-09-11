using Api.Auth;
using Api.DTOs.Grading;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/gradecorrections")]
public class GradeCorrectionsController : ControllerBase
{
    private readonly IGradeCorrectionService _correctionService;

    public GradeCorrectionsController(IGradeCorrectionService correctionService)
    {
        _correctionService = correctionService;
    }

    [HttpPost]
    public async Task<IActionResult> RequestCorrection([FromBody] CreateGradeCorrectionDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var result = await _correctionService.RequestCorrectionAsync(dto, authenticatedUserId);
            return CreatedAtAction(nameof(GetById), new { id = result.CorrectionId }, result);
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

    [HttpGet("pending")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> GetPending()
    {
        var pendingList = await _correctionService.GetPendingAsync();
        return Ok(pendingList);
    }

    [HttpGet("mine")]
    public async Task<IActionResult> GetMyCorrections()
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var list = await _correctionService.GetMyCorrectionsAsync(authenticatedUserId);
        return Ok(list);
    }

    [HttpPatch("{id:guid}/approve")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> ApproveCorrection(Guid id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid reviewerUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var result = await _correctionService.ApproveCorrectionAsync(id, reviewerUserId);
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

    [HttpPatch("{id:guid}/reject")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> RejectCorrection(Guid id, [FromBody] ReviewGradeCorrectionDto? dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid reviewerUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var result = await _correctionService.RejectCorrectionAsync(id, reviewerUserId, dto?.Reason);
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

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId ||
            !HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int authenticatedUserRole)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var correction = await _correctionService.GetByIdAsync(id, authenticatedUserId, authenticatedUserRole);
            if (correction == null)
            {
                return NotFound(new { message = $"GradeCorrection with ID '{id}' was not found." });
            }

            return Ok(correction);
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
    }
}
