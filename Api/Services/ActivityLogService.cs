using Api.Auth;
using Api.Common;
using Api.Domain.Audit;
using Api.Domain.Enrollment;
using Api.DTOs.Audit;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Api.Services;

/// <summary>
/// Records staff actions for the activity log. Every method swallows its own errors:
/// a failure to log must never undo or fail the action itself.
/// </summary>
public interface IActivityLogService
{
    Task LogAsync(Guid? actorId, string action, string summary, Guid? studentId = null, Guid? termId = null);

    /// <summary>"IT 101 - Intro (BSIT 1A)" for a study load, plus its student and term.</summary>
    Task<(string Label, Guid StudentId, Guid TermId, int Status)?> DescribeLoadAsync(Guid studyLoadId);

    /// <summary>The overload approval this actor saved for the student and term since <paramref name="since"/>, if any.</summary>
    Task<(decimal Units, decimal MaxUnits, string Reason)?> RecentOverloadAsync(Guid studentId, Guid termId, Guid actorId, DateTime since);

    /// <summary>The student and term a grade belongs to, for logging corrections.</summary>
    Task<(Guid StudentId, Guid TermId)?> DescribeGradeAsync(Guid gradeId);

    /// <summary>Current year level of each student, read before a change so the log can show old and new.</summary>
    Task<Dictionary<Guid, int?>> YearLevelsAsync(IEnumerable<Guid> studentIds);

    Task<ActivityLogPageDto> SearchAsync(DateTime? from, DateTime? to, string? action, Guid? studentId, Guid? actorId, int page, int pageSize);
}

public class ActivityLogService : IActivityLogService
{
    private readonly AppDbContext _context;
    private readonly ILogger<ActivityLogService> _logger;

    public ActivityLogService(AppDbContext context, ILogger<ActivityLogService> logger)
    {
        _context = context;
        _logger = logger;
    }

    private async Task<string?> NameOfAsync(Guid? userId)
    {
        if (!userId.HasValue) return null;
        var ud = await _context.UserDetails.AsNoTracking().FirstOrDefaultAsync(u => u.UserID == userId.Value);
        return ud != null ? $"{ud.Firstname} {ud.Lastname}".Trim() : null;
    }

    public async Task LogAsync(Guid? actorId, string action, string summary, Guid? studentId = null, Guid? termId = null)
    {
        try
        {
            int? role = actorId.HasValue
                ? await _context.Users.AsNoTracking().Where(u => u.UserID == actorId.Value).Select(u => (int?)u.Role).FirstOrDefaultAsync()
                : null;
            _context.ActivityLogs.Add(new ActivityLog
            {
                ActivityLogID = Guid.NewGuid(),
                OccurredAt = DateTime.UtcNow,
                ActorUserID = actorId,
                ActorName = await NameOfAsync(actorId) ?? (actorId.HasValue ? "Unknown staff" : "Not signed in"),
                ActorRole = role,
                Action = action,
                StudentUserID = studentId,
                StudentName = await NameOfAsync(studentId),
                TermID = termId,
                Summary = summary.Length > 1000 ? summary[..1000] : summary
            });
            await _context.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not write activity log entry {Action}", action);
        }
    }

    public async Task<(string Label, Guid StudentId, Guid TermId, int Status)?> DescribeLoadAsync(Guid studyLoadId)
    {
        try
        {
            var load = await _context.StudyLoads
                .AsNoTracking()
                .Include(sl => sl.Class)
                    .ThenInclude(c => c!.Subject)
                .FirstOrDefaultAsync(sl => sl.StudyLoadID == studyLoadId);
            if (load?.Class == null) return null;
            string label = $"{load.Class.Subject?.SubjectCode ?? "?"} ({load.Class.ClassName})";
            return (label, load.UserID, load.Class.TermID, load.LoadStatus);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not describe study load {Id} for the activity log", studyLoadId);
            return null;
        }
    }

    public async Task<(decimal Units, decimal MaxUnits, string Reason)?> RecentOverloadAsync(Guid studentId, Guid termId, Guid actorId, DateTime since)
    {
        try
        {
            var o = await _context.OverloadApprovals.AsNoTracking()
                .FirstOrDefaultAsync(a => a.UserID == studentId && a.TermID == termId && a.ApprovedByUserID == actorId && a.ApprovedAt >= since);
            return o == null ? null : (o.Units, o.MaxUnits, o.Reason);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not read overload approval for the activity log");
            return null;
        }
    }

    public async Task<(Guid StudentId, Guid TermId)?> DescribeGradeAsync(Guid gradeId)
    {
        try
        {
            var g = await _context.Grades.AsNoTracking()
                .Where(x => x.GradeID == gradeId && x.StudyLoad != null && x.StudyLoad.Class != null)
                .Select(x => new { x.StudyLoad!.UserID, x.StudyLoad.Class!.TermID })
                .FirstOrDefaultAsync();
            return g == null ? null : (g.UserID, g.TermID);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not describe grade {Id} for the activity log", gradeId);
            return null;
        }
    }

    public async Task<Dictionary<Guid, int?>> YearLevelsAsync(IEnumerable<Guid> studentIds)
    {
        var ids = studentIds.Distinct().ToList();
        try
        {
            return await _context.UserDetails.AsNoTracking()
                .Where(u => ids.Contains(u.UserID))
                .ToDictionaryAsync(u => u.UserID, u => u.YearLevel);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not read year levels for the activity log");
            return new Dictionary<Guid, int?>();
        }
    }

    public async Task<ActivityLogPageDto> SearchAsync(DateTime? from, DateTime? to, string? action, Guid? studentId, Guid? actorId, int page, int pageSize)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 200);

        var query = _context.ActivityLogs.AsNoTracking().AsQueryable();
        if (from.HasValue) query = query.Where(l => l.OccurredAt >= from.Value);
        if (to.HasValue) query = query.Where(l => l.OccurredAt < to.Value);
        if (!string.IsNullOrWhiteSpace(action)) query = query.Where(l => l.Action == action);
        if (studentId.HasValue) query = query.Where(l => l.StudentUserID == studentId.Value);
        if (actorId.HasValue) query = query.Where(l => l.ActorUserID == actorId.Value);

        int total = await query.CountAsync();
        var items = await query
            .OrderByDescending(l => l.OccurredAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var termIds = items.Where(i => i.TermID.HasValue).Select(i => i.TermID!.Value).Distinct().ToList();
        var terms = await _context.AcademicTerms.AsNoTracking()
            .Where(t => termIds.Contains(t.TermID))
            .ToDictionaryAsync(t => t.TermID, t => TermLabel.Format(t.SchoolYear, t.Semester));

        return new ActivityLogPageDto
        {
            Page = page,
            PageSize = pageSize,
            TotalCount = total,
            Items = items.Select(l => new ActivityLogEntryDto
            {
                Id = l.ActivityLogID,
                OccurredAt = l.OccurredAt,
                ActorUserId = l.ActorUserID,
                ActorName = l.ActorName,
                ActorRole = l.ActorRole,
                Action = l.Action,
                StudentUserId = l.StudentUserID,
                StudentName = l.StudentName,
                TermLabel = l.TermID.HasValue ? terms.GetValueOrDefault(l.TermID.Value) : null,
                Summary = l.Summary
            }).ToList()
        };
    }
}

/// <summary>Controller helpers: the log is optional so controllers built without it (unit tests) still work.</summary>
public static class ActivityLogControllerExtensions
{
    public static IActivityLogService? ActivityLog(this ControllerBase controller) =>
        controller.HttpContext?.RequestServices?.GetService(typeof(IActivityLogService)) as IActivityLogService;

    public static Guid? CallerId(this ControllerBase controller) =>
        controller.HttpContext?.Items.TryGetValue("user_id", out var id) == true && id is Guid g ? g : null;

    public static string LoadStatusText(int status) => StudyLoadStatus.GetDisplayText(status);
}
