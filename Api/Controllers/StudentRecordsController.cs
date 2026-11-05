using Api.Auth;
using Api.Domain.Audit;
using Api.DTOs.Records;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>A student's academic record: curriculum evaluation and the Transcript of Records.</summary>
[ApiController]
[Route("api/student-records")]
[RequireRegistrarCollegeHeadOrAdmin]
public class StudentRecordsController : ControllerBase
{
    private readonly IStudentRecordService _records;

    public StudentRecordsController(IStudentRecordService records)
    {
        _records = records;
    }

    [HttpGet("{userId:guid}/evaluation")]
    public Task<IActionResult> Evaluation(Guid userId) => Run(() => _records.GetEvaluationAsync(userId));

    [HttpGet("{userId:guid}/transcript")]
    public Task<IActionResult> Transcript(Guid userId) => Run(() => _records.GetTranscriptAsync(userId));

    [HttpGet("{userId:guid}/personal-details")]
    public Task<IActionResult> PersonalDetails(Guid userId) => Run(() => _records.GetPersonalDetailsAsync(userId));

    [HttpPut("{userId:guid}/personal-details")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> UpdatePersonalDetails(Guid userId, [FromBody] UpdatePersonalDetailsDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid callerId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }
        var result = await Run(() => _records.UpdatePersonalDetailsAsync(userId, dto, callerId));
        var log = this.ActivityLog();
        if (result is OkObjectResult && log != null)
        {
            await log.LogAsync(callerId, ActivityActions.PersonalDetailsUpdated, "Updated personal details for the records", userId);
        }
        return result;
    }

    private async Task<IActionResult> Run<T>(Func<Task<T>> read)
    {
        try
        {
            return Ok(await read());
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
}
