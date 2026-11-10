using Api.Auth;
using Api.Domain.Audit;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>Imports old students and their grades from the registrar's Excel files.</summary>
[ApiController]
[Route("api/import")]
public class RecordsImportController : ControllerBase
{
    private readonly IRecordsImportService _service;

    public RecordsImportController(IRecordsImportService service)
    {
        _service = service;
    }

    /// <summary>
    /// Multipart form: gradesFile (GRADES.xlsx, one sheet per term such as "1ST SEM_2025-2026"), optional studentsFile
    /// (STUDENTS.xlsx; its newest sheet gives current year levels), schoolYears ("2025-2026", comma-separated; empty only
    /// lists what is in the file), dryRun (default true) and releaseGrades (default true).
    /// </summary>
    [HttpPost("records")]
    [RequireRegistrarOrAdmin]
    [RequestSizeLimit(20_000_000)]
    public async Task<IActionResult> ImportRecords()
    {
        if (this.CallerId() is not { } callerId) return Unauthorized(new { message = "Authentication required." });
        if (!Request.HasFormContentType)
        {
            return BadRequest(new { message = "Send the Excel files as a form upload." });
        }
        var form = await Request.ReadFormAsync();
        var gradesFile = form.Files.GetFile("gradesFile");
        var studentsFile = form.Files.GetFile("studentsFile");
        var schoolYears = form["schoolYears"].ToString();
        bool dryRun = !bool.TryParse(form["dryRun"], out var d) || d;
        bool releaseGrades = !bool.TryParse(form["releaseGrades"], out var r) || r;
        bool onlyExisting = bool.TryParse(form["onlyExistingStudents"], out var o) && o;
        if (gradesFile == null || gradesFile.Length == 0)
        {
            return BadRequest(new { message = "Choose the grades Excel file." });
        }

        var years = (schoolYears ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        try
        {
            await using var grades = gradesFile.OpenReadStream();
            await using var students = studentsFile is { Length: > 0 } ? studentsFile.OpenReadStream() : null;
            var result = await _service.ImportAsync(grades, students, years, dryRun, releaseGrades, callerId, onlyExisting);
            if (!dryRun && this.ActivityLog() is { } log && (result.NewStudents > 0 || result.GradesPassed + result.GradesFailed + result.Dropped + result.NoGradeYet > 0))
            {
                await log.LogAsync(callerId, ActivityActions.RecordsImported,
                    $"Imported SY {string.Join(", ", result.SchoolYearsImported)} from Excel: {result.NewStudents} new student(s), " +
                    $"{result.GradesPassed + result.GradesFailed} grade(s), {result.Dropped} dropped, {result.NoGradeYet} without a grade");
            }
            return Ok(result);
        }
        catch (InvalidDataException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
