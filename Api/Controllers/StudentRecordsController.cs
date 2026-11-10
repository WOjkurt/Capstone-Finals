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
        var log = this.ActivityLog();
        Api.DTOs.Records.PersonalDetailsDto? before = null;
        if (log != null)
        {
            try { before = await _records.GetPersonalDetailsAsync(userId); }
            catch (KeyNotFoundException) { }
        }
        var result = await Run(() => _records.UpdatePersonalDetailsAsync(userId, dto, callerId));
        if (result is OkObjectResult { Value: Api.DTOs.Records.PersonalDetailsDto after } && log != null)
        {
            var renamed = before != null && (before.Firstname != after.Firstname || before.Lastname != after.Lastname)
                ? $"; name {before.Firstname} {before.Lastname} -> {after.Firstname} {after.Lastname}" : "";
            await log.LogAsync(callerId, ActivityActions.PersonalDetailsUpdated, "Updated personal details for the records" + renamed, userId);
        }
        return result;
    }

    public class SetSexDto
    {
        public string Sex { get; set; } = string.Empty;
    }

    /// <summary>Sets only the student's sex, e.g. from the "Fill in missing sex" list.</summary>
    [HttpPut("{userId:guid}/sex")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> SetSex(Guid userId, [FromBody] SetSexDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid callerId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }
        var result = await Run(async () =>
        {
            await _records.SetSexAsync(userId, dto.Sex, callerId);
            return new { saved = true };
        });
        var log = this.ActivityLog();
        if (result is OkObjectResult && log != null)
        {
            await log.LogAsync(callerId, ActivityActions.PersonalDetailsUpdated, $"Set sex to {dto.Sex.Trim()}", userId);
        }
        return result;
    }

    /// <summary>Irregular students and their progress back to regular (6 units of back majors).</summary>
    [HttpGet("irregular")]
    public Task<IActionResult> Irregular() => Run(() => _records.GetIrregularStudentsAsync());

    /// <summary>Moves the student to another program (logged). Their subjects and grades stay on record.</summary>
    [HttpPost("{userId:guid}/shift")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Shift(Guid userId, [FromBody] ShiftProgramDto dto)
    {
        var result = await Run(() => _records.ShiftProgramAsync(userId, dto));
        var log = this.ActivityLog();
        if (result is OkObjectResult ok && ok.Value is ShiftResultDto shift && log != null)
        {
            await log.LogAsync(this.CallerId(), ActivityActions.ProgramShifted,
                $"Shifted from {shift.FromProgramCode ?? "no program"} to {shift.ProgramCode}: {dto.Reason.Trim()}", userId);
        }
        return result;
    }

    /// <summary>Every subject taken, with or without a grade (residency record and grade sheet).</summary>
    [HttpGet("{userId:guid}/grades")]
    public Task<IActionResult> Grades(Guid userId) => Run(() => _records.GetGradeRowsAsync(userId));

    [HttpGet("{userId:guid}/previous-program-subjects")]
    public Task<IActionResult> PreviousProgramSubjects(Guid userId) => Run(() => _records.GetPreviousProgramSubjectsAsync(userId));

    [HttpGet("{userId:guid}/standing")]
    public Task<IActionResult> Standing(Guid userId) => Run(() => _records.GetStandingAsync(userId));

    /// <summary>Marks the student regular or irregular (logged).</summary>
    [HttpPut("{userId:guid}/standing")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> SetStanding(Guid userId, [FromBody] SetStandingDto dto)
    {
        var result = await Run(() => _records.SetStandingAsync(userId, dto.IsRegular));
        var log = this.ActivityLog();
        if (result is OkObjectResult ok && ok.Value is StandingDto standing && log != null)
        {
            await log.LogAsync(this.CallerId(), ActivityActions.StandingChanged,
                standing.IsRegular
                    ? $"Marked regular ({standing.BackMajorUnitsPassed:0.#} back major units passed)"
                    : "Marked irregular",
                userId);
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
