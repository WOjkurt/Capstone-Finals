using Api.Domain.Enrollment;
using Api.DTOs.StudyLoad;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface IStudyLoadChangeService
{
    /// <summary>True when the student already has an Enrolled subject in the term, so a new subject is an "add".</summary>
    Task<bool> IsEnrolledInTermAsync(Guid userId, Guid termId);
    Task<Guid?> TermOfClassAsync(Guid classId);
    Task<int?> StatusOfAsync(Guid studyLoadId);
    Task RecordAsync(Guid studyLoadId, string kind, string? reason, Guid? changedBy);
    /// <summary>Records an "Added" change only for a load created at or after [since] (not one that already existed).</summary>
    Task RecordAddedIfNewAsync(Guid studyLoadId, DateTime since, string? reason, Guid? changedBy);
    Task<List<StudyLoadChangeDto>> GetAsync(Guid userId, Guid termId);
}

/// <summary>Adds and drops after enrollment, for the Adding/Dropping form.</summary>
public class StudyLoadChangeService : IStudyLoadChangeService
{
    private readonly AppDbContext _context;

    public StudyLoadChangeService(AppDbContext context)
    {
        _context = context;
    }

    public Task<bool> IsEnrolledInTermAsync(Guid userId, Guid termId) =>
        _context.StudyLoads.AnyAsync(sl => sl.UserID == userId && sl.LoadStatus == StudyLoadStatus.Enrolled &&
                                           sl.Class != null && sl.Class.TermID == termId);

    public async Task<Guid?> TermOfClassAsync(Guid classId) =>
        await _context.Classes.Where(c => c.ClassID == classId).Select(c => (Guid?)c.TermID).FirstOrDefaultAsync();

    public async Task<int?> StatusOfAsync(Guid studyLoadId) =>
        await _context.StudyLoads.Where(sl => sl.StudyLoadID == studyLoadId).Select(sl => (int?)sl.LoadStatus).FirstOrDefaultAsync();

    public async Task RecordAddedIfNewAsync(Guid studyLoadId, DateTime since, string? reason, Guid? changedBy)
    {
        var isNew = await _context.StudyLoads.AnyAsync(sl => sl.StudyLoadID == studyLoadId &&
                                                            sl.LoadStatus == StudyLoadStatus.Enrolled && sl.CreatedAt >= since);
        if (isNew) await RecordAsync(studyLoadId, StudyLoadChangeKinds.Added, reason, changedBy);
    }

    public async Task RecordAsync(Guid studyLoadId, string kind, string? reason, Guid? changedBy)
    {
        var load = await _context.StudyLoads.AsNoTracking()
            .Where(sl => sl.StudyLoadID == studyLoadId && sl.Class != null)
            .Select(sl => new { sl.UserID, sl.Class!.TermID })
            .FirstOrDefaultAsync();
        if (load == null) return;
        _context.StudyLoadChanges.Add(new StudyLoadChange
        {
            ChangeID = Guid.NewGuid(),
            StudyLoadID = studyLoadId,
            UserID = load.UserID,
            TermID = load.TermID,
            Kind = kind,
            Reason = string.IsNullOrWhiteSpace(reason) ? null : reason.Trim(),
            ChangedByUserID = changedBy,
            ChangedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();
    }

    public async Task<List<StudyLoadChangeDto>> GetAsync(Guid userId, Guid termId)
    {
        var rows = await _context.StudyLoadChanges.AsNoTracking()
            .Where(c => c.UserID == userId && c.TermID == termId)
            .Select(c => new
            {
                c.ChangeID,
                c.StudyLoadID,
                c.Kind,
                c.Reason,
                c.ChangedByUserID,
                c.ChangedAt,
                Code = c.StudyLoad!.Class!.Subject!.SubjectCode,
                Title = c.StudyLoad.Class.Subject.SubjectTitle,
                c.StudyLoad.Class.ClassName,
                Units = c.StudyLoad.Class.Subject.LecUnits + c.StudyLoad.Class.Subject.LabUnits
            })
            .ToListAsync();
        var staffIds = rows.Where(r => r.ChangedByUserID.HasValue).Select(r => r.ChangedByUserID!.Value).Distinct().ToList();
        var names = await _context.UserDetails.AsNoTracking()
            .Where(u => staffIds.Contains(u.UserID))
            .ToDictionaryAsync(u => u.UserID, u => $"{u.Firstname} {u.Lastname}".Trim());
        return rows
            .OrderBy(r => r.ChangedAt)
            .Select(r => new StudyLoadChangeDto
            {
                ChangeId = r.ChangeID,
                StudyLoadId = r.StudyLoadID,
                Kind = r.Kind,
                SubjectCode = r.Code,
                SubjectTitle = r.Title,
                ClassName = r.ClassName,
                Units = r.Units,
                Reason = r.Reason,
                ChangedBy = r.ChangedByUserID.HasValue ? names.GetValueOrDefault(r.ChangedByUserID.Value) : null,
                ChangedAt = r.ChangedAt
            })
            .ToList();
    }
}

public static class StudyLoadChangeControllerExtensions
{
    /// <summary>The change recorder, or null when the controller is built without services (unit tests).</summary>
    public static IStudyLoadChangeService? LoadChanges(this ControllerBase controller) =>
        controller.HttpContext?.RequestServices?.GetService(typeof(IStudyLoadChangeService)) as IStudyLoadChangeService;
}
