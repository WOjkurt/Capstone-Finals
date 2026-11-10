using Api.Auth;
using Api.Common;
using Api.Data;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[RequireRegistrarCollegeHeadOrAdmin]
public class StudentsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IUserDetailsRepository _userDetailsRepository;

    public StudentsController(AppDbContext context, IUserDetailsRepository userDetailsRepository)
    {
        _context = context;
        _userDetailsRepository = userDetailsRepository;
    }

    [HttpGet("search")]
    [EnableRateLimiting("search")]
    public async Task<IActionResult> Search([FromQuery] string? q, [FromQuery] bool? missingLrn, [FromQuery] int? programId)
    {
        // Must be Student role only
        var query = _context.UserDetails
            .AsNoTracking()
            .Include(ud => ud.User)
            .Include(ud => ud.Program)
            .Include(ud => ud.Curriculum)
            .Where(ud => ud.User != null && ud.User.Role == RoleUtils.Student);

        if (programId.HasValue)
        {
            query = query.Where(ud => ud.ProgramID == programId.Value);
        }

        if (missingLrn == true)
        {
            query = query.Where(ud => ud.LRN == null || ud.LRN == "");
        }

        // A whole student ID (e.g. 25060208) finds that student directly. 12 digits is an LRN instead.
        var numberResult = StudentIdHelper.Normalize(q);
        if (!string.IsNullOrWhiteSpace(q) && numberResult.IsValid && numberResult.Number is { Length: not LrnHelper.RequiredDigits } number)
        {
            query = query.Where(ud => ud.StudentID == number);
        }
        else if (!string.IsNullOrWhiteSpace(q))
        {
            var lrnResult = LrnHelper.Normalize(q);
            var isPostgres = _context.Database.IsNpgsql();
            var term = q.Trim();

            if (lrnResult.IsValid && lrnResult.Lrn != null)
            {
                var exactLrn = lrnResult.Lrn;

                if (isPostgres)
                {
                    var escaped = term.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_");
                    query = query.Where(ud =>
                        ud.LRN == exactLrn ||
                        EF.Functions.ILike(ud.Firstname, $"%{escaped}%", "\\") ||
                        EF.Functions.ILike(ud.Lastname, $"%{escaped}%", "\\") ||
                        (ud.User != null && EF.Functions.ILike(ud.User.Email, $"%{escaped}%", "\\"))
                    );
                }
                else
                {
                    var lower = term.ToLower();
                    query = query.Where(ud =>
                        ud.LRN == exactLrn ||
                        ud.Firstname.ToLower().Contains(lower) ||
                        ud.Lastname.ToLower().Contains(lower) ||
                        (ud.User != null && ud.User.Email.ToLower().Contains(lower))
                    );
                }
            }
            else
            {
                if (isPostgres)
                {
                    var escaped = term.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_");
                    query = query.Where(ud =>
                        EF.Functions.ILike(ud.Firstname, $"%{escaped}%", "\\") ||
                        EF.Functions.ILike(ud.Lastname, $"%{escaped}%", "\\") ||
                        (ud.User != null && EF.Functions.ILike(ud.User.Email, $"%{escaped}%", "\\"))
                    );
                }
                else
                {
                    var lower = term.ToLower();
                    query = query.Where(ud =>
                        ud.Firstname.ToLower().Contains(lower) ||
                        ud.Lastname.ToLower().Contains(lower) ||
                        (ud.User != null && ud.User.Email.ToLower().Contains(lower))
                    );
                }
            }
        }

        var list = await query
            .OrderBy(ud => ud.Lastname)
            .ThenBy(ud => ud.Firstname)
            .Take(20)
            .ToListAsync();

        var results = list.Select(ud => new StudentSearchResultDto
        {
            UserId = ud.UserID,
            FullName = $"{ud.Firstname} {ud.Lastname}".Trim(),
            Email = ud.User?.Email,
            HasSignedIn = ud.User == null || !ud.User.FirebaseUID.StartsWith(Api.Services.RecordsImportService.PendingUidPrefix),
            Lrn = ud.LRN,
            StudentID = ud.StudentID,
            HasLrn = !string.IsNullOrWhiteSpace(ud.LRN),
            ProgramId = ud.ProgramID,
            ProgramCode = ud.Program?.ProgramCode,
            ProgramName = ud.Program?.FullName,
            YearLevel = ud.YearLevel,
            CurriculumId = ud.CurriculumID,
            CurriculumName = ud.Curriculum?.Name,
            StudentType = ud.StudentType,
            StudentStatus = ud.StudentStatus,
            Status = ud.StudentStatus.HasValue ? ud.StudentStatus.Value.ToString() : null
        }).ToList();

        return Ok(results);
    }
    /// <summary>
    /// Sets the school email of a student who was imported from the registrar's records and has not signed in yet.
    /// Their first sign-in with this email makes the account theirs. After that the email comes from their sign-in.
    /// </summary>
    [HttpPatch("{userId:guid}/school-email")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> SetSchoolEmail(Guid userId, [FromBody] SetSchoolEmailDto dto)
    {
        if (this.CallerId() is not { } callerId) return Unauthorized(new { message = "Authentication required." });

        var user = await _context.Users.FirstOrDefaultAsync(u => u.UserID == userId && u.Role == RoleUtils.Student);
        if (user == null) return NotFound(new { message = "Student not found." });
        if (!user.FirebaseUID.StartsWith(Api.Services.RecordsImportService.PendingUidPrefix))
        {
            return Conflict(new { message = "This student has already signed in; their email is the one they sign in with." });
        }

        var email = (dto.SchoolEmail ?? "").Trim().ToLowerInvariant();
        if (email.Length > 0)
        {
            var domain = SchoolEmailValidator.GetAllowedDomain(HttpContext.RequestServices.GetService<IConfiguration>());
            if (!System.Net.Mail.MailAddress.TryCreate(email, out var parsed) || parsed.Address != email ||
                !SchoolEmailValidator.IsValidDomain(email, domain))
            {
                return BadRequest(new { message = $"Enter a school email that ends with @{domain}." });
            }
            var other = await _context.Users.AsNoTracking()
                .Where(u => u.UserID != userId && u.Email.ToLower() == email)
                .Select(u => new { u.UserID })
                .FirstOrDefaultAsync();
            if (other != null)
            {
                var name = await _context.UserDetails.AsNoTracking().Where(d => d.UserID == other.UserID)
                    .Select(d => d.Firstname + " " + d.Lastname).FirstOrDefaultAsync();
                return Conflict(new { message = $"{email} already belongs to {name ?? "another account"}." });
            }
        }

        var old = user.Email;
        user.Email = email;
        await _context.SaveChangesAsync();
        if (old != email && this.ActivityLog() is { } log)
        {
            await log.LogAsync(callerId, Api.Domain.Audit.ActivityActions.SchoolEmailSet,
                $"School email {(old.Length == 0 ? "not set" : old)} -> {(email.Length == 0 ? "not set" : email)}", userId);
        }
        return Ok(new { userId, schoolEmail = email, hasSignedIn = false });
    }
}

public class SetSchoolEmailDto
{
    public string? SchoolEmail { get; set; }
}
