using Api.Auth;
using Api.DTOs.Curriculum;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CurriculumController : ControllerBase
{
    private readonly ICurriculumImportService _curriculumImportService;
    private readonly ILogger<CurriculumController> _logger;

    public CurriculumController(
        ICurriculumImportService curriculumImportService,
        ILogger<CurriculumController> logger)
    {
        _curriculumImportService = curriculumImportService;
        _logger = logger;
    }

    [HttpPost("import")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Import(
        [FromForm] IFormFile? file,
        [FromQuery] bool dryRun = true,
        [FromQuery] bool updateExisting = false)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid callerUserId || callerUserId == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        // Fallback for multipart form uploads where form field name might not be "file"
        if (file == null && Request.HasFormContentType && Request.Form.Files.Count > 0)
        {
            file = Request.Form.Files[0];
        }

        if (file == null || file.Length == 0)
        {
            var emptyResult = new CurriculumImportResponseDto
            {
                DryRun = dryRun,
                Errors = new List<CurriculumImportFindingDto>
                {
                    new() { Row = 0, Code = "", Message = "A non-empty CSV file is required." }
                },
                TotalErrors = 1
            };

            _logger.LogInformation(
                "Curriculum import failed validation: CallerID={CallerId}, DryRun={DryRun}, UpdateExisting={UpdateExisting}, Program={Program}, Created=0, Updated=0, Unchanged=0, PrereqsToAdd=0, CoreqsToAdd=0, AlreadyExist=0, ExtrasInDb=0, TotalWarnings=0, TotalErrors=1",
                callerUserId, dryRun, updateExisting, "");

            return BadRequest(emptyResult);
        }

        using var stream = file.OpenReadStream();
        var result = await _curriculumImportService.ImportAsync(
            stream,
            file.FileName,
            file.Length,
            dryRun,
            updateExisting,
            callerUserId);

        _logger.LogInformation(
            "Curriculum import executed: CallerID={CallerId}, DryRun={DryRun}, UpdateExisting={UpdateExisting}, Program={Program}, Created={Created}, Updated={Updated}, Unchanged={Unchanged}, PrereqsToAdd={PrereqsToAdd}, CoreqsToAdd={CoreqsToAdd}, AlreadyExist={AlreadyExist}, ExtrasInDb={ExtrasInDb}, TotalWarnings={TotalWarnings}, TotalErrors={TotalErrors}",
            callerUserId,
            result.DryRun,
            updateExisting,
            result.Program,
            result.Subjects.Create,
            result.Subjects.Update,
            result.Subjects.Unchanged,
            result.Requisites.PrerequisitesToAdd,
            result.Requisites.CorequisitesToAdd,
            result.Requisites.AlreadyExist,
            result.Requisites.ExtrasInDatabase,
            result.TotalWarnings,
            result.TotalErrors);

        if (result.TotalErrors > 0)
        {
            return BadRequest(result);
        }

        return Ok(result);
    }
}
