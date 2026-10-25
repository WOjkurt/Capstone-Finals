using Api.Auth;
using Api.Common;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Logging;
using System.ComponentModel.DataAnnotations;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UserDetailsController : ControllerBase
{
    private readonly IUserDetailsRepository _userDetailsRepository;
    private readonly IProgramScopingService _scopingService;
    private readonly ILogger<UserDetailsController> _logger;

    public UserDetailsController(
        IUserDetailsRepository userDetailsRepository,
        IProgramScopingService scopingService,
        ILogger<UserDetailsController> logger)
    {
        _userDetailsRepository = userDetailsRepository;
        _scopingService = scopingService;
        _logger = logger;
    }

    [HttpGet]
    [EnableRateLimiting("search")]
    public async Task<IActionResult> Search([FromQuery, StringLength(100)] string? search, [FromQuery, Range(1, 6)] int? role)
    {
        if (!HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int authRole)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        bool isRegistrarOrAdmin = authRole == RoleUtils.Registrar || authRole == RoleUtils.Admin;
        bool isProgramHeadSearchingTeachers = authRole == RoleUtils.ProgramHead && role == RoleUtils.Teacher;
        bool isCollegeHeadSearchingTeachers = authRole == RoleUtils.CollegeHead && role == RoleUtils.Teacher;

        if (!isRegistrarOrAdmin && !isProgramHeadSearchingTeachers && !isCollegeHeadSearchingTeachers)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Access denied. Registrar or Admin privileges required." });
        }

        int? programScope = null;
        int? limit = 50;

        if (authRole == RoleUtils.ProgramHead)
        {
            if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authUserId || authUserId == Guid.Empty)
            {
                return Unauthorized(new { message = "Authentication required." });
            }

            programScope = await _scopingService.GetProgramIdAsync(authUserId);
            if (!programScope.HasValue)
            {
                // Program Head without an assigned program gets an empty list
                return Ok(new List<UserSearchResultDto>());
            }

            // Remove the 50 limit for Program Head viewing their department's faculty roster
            limit = null;
        }
        else if (authRole == RoleUtils.CollegeHead)
        {
            // Remove limit for College Head viewing all teachers across all programs
            limit = null;
        }

        var list = await _userDetailsRepository.SearchAsync(search, role, programScope, limit);
        var dtos = list.Select(ud => new UserSearchResultDto
        {
            UserID = ud.UserID,
            Firstname = ud.Firstname,
            Lastname = ud.Lastname,
            Email = ud.User?.Email ?? string.Empty,
            ProgramID = ud.ProgramID,
            ProgramCode = ud.Program?.ProgramCode,
            YearLevel = ud.YearLevel,
            StudentStatus = ud.StudentStatus,
            Role = ud.User?.Role ?? 0,
            RoleName = ud.User != null ? RoleUtils.GetRoleName(ud.User.Role) : "Unknown"
        }).ToList();

        return Ok(dtos);
    }

    [HttpGet("me")]
    public async Task<IActionResult> GetMyUserDetails()
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authenticatedUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var userDetails = await _userDetailsRepository.GetByUserIdAsync(authenticatedUserId);
        if (userDetails == null)
        {
            return NotFound(new { message = "No user details found for current user." });
        }

        var dto = new UserDetailsDto
        {
            UserDetailID = userDetails.UserDetailID,
            UserID = userDetails.UserID,
            Firstname = userDetails.Firstname,
            Lastname = userDetails.Lastname,
            LRN = userDetails.LRN,
            ProgramID = userDetails.ProgramID,
            ProgramCode = userDetails.Program?.ProgramCode,
            ProgramName = userDetails.Program?.ProgramName,
            StudentType = userDetails.StudentType,
            StudentStatus = userDetails.StudentStatus,
            YearLevel = userDetails.YearLevel,
            EmployeeID = userDetails.EmployeeID,
            PositionID = userDetails.PositionID,
            IsRegular = userDetails.IsRegular
        };

        return Ok(dto);
    }

    [HttpPatch("{userId:guid}/lrn")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> UpdateLrn(Guid userId, [FromBody] UpdateLrnRequestDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var callerUserIdObj) || callerUserIdObj is not Guid callerUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var userDetails = await _userDetailsRepository.GetByUserIdAsync(userId);
        if (userDetails == null)
        {
            return NotFound(new { message = "User details not found." });
        }

        if (userDetails.User?.Role != RoleUtils.Student)
        {
            return BadRequest(new { message = "LRN can only be set for students." });
        }

        var lrnResult = LrnHelper.Normalize(dto.Lrn);
        if (!lrnResult.IsValid)
        {
            return BadRequest(new { message = lrnResult.ErrorMessage });
        }

        if (lrnResult.Lrn != null)
        {
            var existingWithLrn = await _userDetailsRepository.GetByLrnAsync(lrnResult.Lrn);
            if (existingWithLrn != null && existingWithLrn.UserID != userId)
            {
                return BadRequest(new { message = "This LRN is already assigned to another student." });
            }
        }

        userDetails.LRN = lrnResult.Lrn;
        await _userDetailsRepository.UpdateAsync(userDetails);

        _logger.LogInformation("LRN updated: StudentID={StudentId}, CallerID={CallerId}", userId, callerUserId);

        return Ok(new
        {
            message = "LRN updated successfully.",
            userId = userDetails.UserID,
            lrn = userDetails.LRN,
            hasLrn = !string.IsNullOrEmpty(userDetails.LRN)
        });
    }

    [HttpPatch("{userId:guid}/year-level")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> UpdateYearLevel(Guid userId, [FromBody] UpdateYearLevelRequestDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var callerUserIdObj) || callerUserIdObj is not Guid callerUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (dto.YearLevel < 1 || dto.YearLevel > 5)
        {
            return BadRequest(new { message = "yearLevel must be between 1 and 5." });
        }

        var userDetails = await _userDetailsRepository.GetByUserIdAsync(userId);
        if (userDetails == null)
        {
            return NotFound(new { message = "User not found or has no user details." });
        }

        if (userDetails.User?.Role != RoleUtils.Student)
        {
            return NotFound(new { message = "User not found or is not a student." });
        }

        var oldYearLevel = userDetails.YearLevel;
        userDetails.YearLevel = dto.YearLevel;
        await _userDetailsRepository.UpdateAsync(userDetails);

        _logger.LogInformation(
            "YearLevel updated: TargetUserID={TargetUserId}, CallerID={CallerId}, OldYearLevel={Old}, NewYearLevel={New}",
            userId, callerUserId, oldYearLevel, dto.YearLevel);

        return Ok(new
        {
            message = "Year level updated successfully.",
            userId = userDetails.UserID,
            yearLevel = userDetails.YearLevel
        });
    }
}
