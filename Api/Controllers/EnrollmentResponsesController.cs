using Api.Auth;
using Api.DTOs.Enrollment;
using Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class EnrollmentResponsesController : ControllerBase
{
    private readonly IEnrollmentService _enrollmentService;

    public EnrollmentResponsesController(IEnrollmentService enrollmentService)
    {
        _enrollmentService = enrollmentService;
    }

    [HttpPost]
    [AllowAnonymous]
    [RequireWebhookSecret]
    [EnableRateLimiting("webhook")]
    [RequestSizeLimit(65_536)] // 64 KB — more than sufficient for a Forms webhook payload
    public async Task<IActionResult> CreateResponse([FromBody] CreateEnrollmentResponseDto dto)
    {
        var responseId = await _enrollmentService.CreateResponseAsync(dto);
        return CreatedAtAction(nameof(GetResponseById), new { id = responseId }, new { responseID = responseId });
    }

    [HttpGet("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> GetResponseById(Guid id)
    {
        var response = await _enrollmentService.GetResponseByIdAsync(id);
        if (response == null)
        {
            return NotFound(new { message = $"EnrollmentResponse with ID '{id}' was not found." });
        }
        return Ok(response);
    }

    [HttpGet("unprocessed")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> GetUnprocessedResponses()
    {
        var responses = await _enrollmentService.GetUnprocessedResponsesAsync();
        return Ok(responses);
    }
}
