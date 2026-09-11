using Api.Auth;
using Api.DTOs.Enrollment;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class EnrollmentResponsesController : ControllerBase
{
    private readonly IEnrollmentService _enrollmentService;
    private readonly IConfiguration _configuration;

    public EnrollmentResponsesController(IEnrollmentService enrollmentService, IConfiguration configuration)
    {
        _enrollmentService = enrollmentService;
        _configuration = configuration;
    }

    [HttpPost]
    public async Task<IActionResult> CreateResponse([FromBody] CreateEnrollmentResponseDto dto)
    {
        string? secretHeader = Request.Headers["X-Webhook-Secret"].FirstOrDefault();
        string? expectedSecret = _configuration["Webhook:GoogleFormsSecret"];

        if (string.IsNullOrEmpty(expectedSecret) || string.IsNullOrEmpty(secretHeader) || secretHeader != expectedSecret)
        {
            return Unauthorized(new { message = "Invalid or missing webhook secret." });
        }

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
