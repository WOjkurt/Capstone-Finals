using Api.Auth;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>Term reports for the Registrar (and Admin).</summary>
[ApiController]
[Route("api/reports")]
[RequireRegistrarOrAdmin]
public class ReportsController : ControllerBase
{
    private readonly IReportService _reports;

    public ReportsController(IReportService reports)
    {
        _reports = reports;
    }

    private async Task<IActionResult> Run<T>(Func<Task<T>> report)
    {
        try
        {
            return Ok(await report());
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpGet("enrollment-summary")]
    public Task<IActionResult> EnrollmentSummary([FromQuery] Guid termId) => Run(() => _reports.GetEnrollmentSummaryAsync(termId));

    [HttpGet("class-sizes")]
    public Task<IActionResult> ClassSizes([FromQuery] Guid termId) => Run(() => _reports.GetClassSizesAsync(termId));

    [HttpGet("failed-students")]
    public Task<IActionResult> FailedStudents([FromQuery] Guid termId) => Run(() => _reports.GetFailedStudentsAsync(termId));

    /// <summary>Dean's list of a term. DBTC's rules are the defaults: GWA 1.7 or better, no grade below 2.3, at least 15 units.</summary>
    [HttpGet("deans-list")]
    public async Task<IActionResult> DeansList([FromQuery] Guid termId, [FromQuery] decimal maxGwa = 1.7m,
        [FromQuery] decimal minUnits = 15m, [FromQuery] decimal worstGrade = 2.3m)
    {
        if (maxGwa is < 1m or > 3m || worstGrade is < 1m or > 3m || minUnits is < 0m or > 40m)
        {
            return BadRequest(new { message = "GWA and lowest grade must be between 1.0 and 3.0, and units between 0 and 40." });
        }
        return await Run(() => _reports.GetDeansListAsync(termId, maxGwa, minUnits, worstGrade));
    }

    [HttpGet("enrollment-statistics")]
    public Task<IActionResult> EnrollmentStatistics([FromQuery] Guid termId) => Run(() => _reports.GetEnrollmentStatisticsAsync(termId));

    /// <summary>Class lists for a term, or one class with <paramref name="classId"/>.</summary>
    [HttpGet("class-lists")]
    public Task<IActionResult> ClassLists([FromQuery] Guid termId, [FromQuery] Guid? classId) => Run(() => _reports.GetClassListsAsync(termId, classId));

    [HttpGet("missing-sex")]
    public Task<IActionResult> MissingSex([FromQuery] Guid termId) => Run(() => _reports.GetStudentsMissingSexAsync(termId));

    [HttpGet("transferees")]
    public async Task<IActionResult> Transferees() => Ok(await _reports.GetTransfereesAsync());

    [HttpGet("teacher-loads")]
    public Task<IActionResult> TeacherLoads([FromQuery] Guid termId) => Run(() => _reports.GetTeacherLoadsAsync(termId));
}
