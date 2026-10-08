using Api.Auth;
using Api.Common;
using Api.Data;
using Api.DTOs.Enrollment;
using Api.Repositories;
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
            .Where(ud => ud.User != null && ud.User.Role == RoleUtils.Student);

        if (programId.HasValue)
        {
            query = query.Where(ud => ud.ProgramID == programId.Value);
        }

        if (missingLrn == true)
        {
            query = query.Where(ud => ud.LRN == null || ud.LRN == "");
        }

        if (!string.IsNullOrWhiteSpace(q))
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
            Lrn = ud.LRN,
            HasLrn = !string.IsNullOrWhiteSpace(ud.LRN),
            ProgramId = ud.ProgramID,
            ProgramCode = ud.Program?.ProgramCode,
            ProgramName = ud.Program?.ProgramName,
            YearLevel = ud.YearLevel,
            StudentType = ud.StudentType,
            StudentStatus = ud.StudentStatus,
            Status = ud.StudentStatus.HasValue ? ud.StudentStatus.Value.ToString() : null
        }).ToList();

        return Ok(results);
    }
}
