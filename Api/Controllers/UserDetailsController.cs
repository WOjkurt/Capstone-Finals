using Api.Auth;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using System.ComponentModel.DataAnnotations;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UserDetailsController : ControllerBase
{
    private readonly IUserDetailsRepository _userDetailsRepository;
    private readonly IProgramScopingService _scopingService;

    public UserDetailsController(
        IUserDetailsRepository userDetailsRepository,
        IProgramScopingService scopingService)
    {
        _userDetailsRepository = userDetailsRepository;
        _scopingService = scopingService;
    }

    [HttpGet]
    [EnableRateLimiting("search")]
    public async Task<IActionResult> Search([FromQuery, StringLength(100)] string? search, [FromQuery, Range(1, 5)] int? role)
    {
        if (!HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int authRole)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        bool isRegistrarOrAdmin = authRole == RoleUtils.Registrar || authRole == RoleUtils.Admin;
        bool isProgramHeadSearchingTeachers = authRole == RoleUtils.ProgramHead && role == RoleUtils.Teacher;

        if (!isRegistrarOrAdmin && !isProgramHeadSearchingTeachers)
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
}
