using Api.Auth;
using Api.Domain.Audit;
using Api.Domain.Enrollment;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>Imports the registrar's lists: credited subjects, and the Google Form's enrollment form answers.</summary>
[ApiController]
[Route("api/import")]
public class CreditsImportController : ControllerBase
{
    private readonly ICreditsImportService _service;
    private readonly IEnrollmentFormsImportService? _forms;

    public CreditsImportController(ICreditsImportService service, IEnrollmentFormsImportService? forms = null)
    {
        _service = service;
        _forms = forms;
    }

    /// <summary>
    /// Multipart form: file (the Google Form's responses spreadsheet as .xlsx) and dryRun (default true). Each answer
    /// becomes the enrollment form of the matching student already in the system.
    /// </summary>
    [HttpPost("enrollment-forms")]
    [RequireRegistrarOrAdmin]
    [RequestSizeLimit(10_000_000)]
    public async Task<IActionResult> ImportEnrollmentForms()
    {
        if (this.CallerId() is not { } callerId) return Unauthorized(new { message = "Authentication required." });
        if (_forms == null) return StatusCode(500);
        if (!Request.HasFormContentType)
        {
            return BadRequest(new { message = "Send the file as a form upload." });
        }
        var form = await Request.ReadFormAsync();
        var file = form.Files.GetFile("file");
        bool dryRun = !bool.TryParse(form["dryRun"], out var d) || d;
        if (file == null || file.Length == 0 || !file.FileName.EndsWith(".xlsx", StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest(new { message = "Choose the form responses file. In Google Sheets: File → Download → Microsoft Excel (.xlsx)." });
        }
        try
        {
            await using var stream = file.OpenReadStream();
            var result = await _forms.ImportAsync(stream, dryRun, callerId);
            if (!dryRun && result.Forms > 0 && this.ActivityLog() is { } log)
            {
                await log.LogAsync(callerId, ActivityActions.FormsImported,
                    $"Imported {result.Forms} enrollment form(s) from {file.FileName}");
            }
            return Ok(result);
        }
        catch (InvalidDataException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>Multipart form: file (.xlsx or .csv, one row per credited subject) and dryRun (default true).</summary>
    [HttpPost("credits")]
    [RequireRegistrarOrAdmin]
    [RequestSizeLimit(10_000_000)]
    public async Task<IActionResult> ImportCredits()
    {
        if (this.CallerId() is not { } callerId) return Unauthorized(new { message = "Authentication required." });
        if (!Request.HasFormContentType)
        {
            return BadRequest(new { message = "Send the file as a form upload." });
        }
        var form = await Request.ReadFormAsync();
        var file = form.Files.GetFile("file");
        bool dryRun = !bool.TryParse(form["dryRun"], out var d) || d;
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "Choose the Excel or CSV file of credited subjects." });
        }
        if (!file.FileName.EndsWith(".xlsx", StringComparison.OrdinalIgnoreCase) &&
            !file.FileName.EndsWith(".csv", StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest(new { message = "Use an Excel (.xlsx) or CSV (.csv) file." });
        }

        try
        {
            await using var stream = file.OpenReadStream();
            var result = await _service.ImportAsync(stream, file.FileName, dryRun, callerId);
            if (!dryRun && result.Added.Count > 0 && this.ActivityLog() is { } log)
            {
                foreach (var (credit, subject) in result.Added)
                {
                    var units = subject.LecUnits + subject.LabUnits;
                    await log.LogAsync(callerId, ActivityActions.CreditAdded,
                        $"Credited {subject.SubjectCode} ({credit.CreditedUnits:0.#} of {units:0.#} units) " +
                        (credit.Kind == CreditKinds.CrossEnrollment ? $"cross-enrolled at {credit.SourceSchool}" : $"from {credit.SourceSchool}") +
                        (credit.Grade != null ? $" (grade {credit.Grade})" : "") + " — imported from file",
                        credit.UserID);
                }
                await log.LogAsync(callerId, ActivityActions.CreditsImported,
                    $"Imported {result.Credits} credited subject(s) for {result.Students} student(s) from {file.FileName}");
            }
            return Ok(result);
        }
        catch (InvalidDataException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
