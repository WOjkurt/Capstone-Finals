using Api.Auth;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UserDetailsController : ControllerBase
{
    private readonly IUserDetailsRepository _userDetailsRepository;

    public UserDetailsController(IUserDetailsRepository userDetailsRepository)
    {
        _userDetailsRepository = userDetailsRepository;
    }

    [HttpGet]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Search([FromQuery] string? search, [FromQuery] int? role)
    {
        var list = await _userDetailsRepository.SearchAsync(search, role);
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
