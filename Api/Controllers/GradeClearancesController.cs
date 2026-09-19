using Api.Auth;
using Api.DTOs.Grading;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/gradeclearances")]
public class GradeClearancesController : ControllerBase
{
    private readonly IGradeClearanceService _clearanceService;
    private readonly IUserDetailsRepository _userDetailsRepository;
    private readonly IProgramScopingService _scopingService;

    public GradeClearancesController(
        IGradeClearanceService clearanceService,
        IUserDetailsRepository userDetailsRepository,
        IProgramScopingService scopingService)
    {
        _clearanceService = clearanceService;
        _userDetailsRepository = userDetailsRepository;
        _scopingService = scopingService;
    }

    [HttpPatch("{userId:guid}/{termId:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> SetClearance(Guid userId, Guid termId, [FromBody] SetGradeClearanceDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid reviewerUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        try
        {
            var result = await _clearanceService.SetClearanceAsync(userId, termId, dto.IsCleared, reviewerUserId);
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

    [HttpGet("{userId:guid}")]
    public async Task<IActionResult> GetByStudent(Guid userId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId ||
            !HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int authenticatedUserRole)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        bool isSelf = authenticatedUserId == userId;
        bool isStaff = authenticatedUserRole == RoleUtils.Registrar ||
                       authenticatedUserRole == RoleUtils.Admin ||
                       authenticatedUserRole == RoleUtils.ProgramHead;

        if (!isSelf && !isStaff)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Access denied. You can only view your own grade clearances unless you are a Registrar, Admin, or Program Head." });
        }

        if (authenticatedUserRole == RoleUtils.ProgramHead && !isSelf)
        {
            var studentDetails = await _userDetailsRepository.GetByUserIdAsync(userId);
            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(authenticatedUserId, studentDetails?.ProgramID, "student");
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        var clearances = await _clearanceService.GetByStudentAsync(userId);
        return Ok(clearances);
    }
}
