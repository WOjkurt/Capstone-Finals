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
