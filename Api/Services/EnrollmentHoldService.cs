using Api.Auth;
using Api.Domain.Enrollment;
using Api.DTOs.Holds;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface IEnrollmentHoldService
{
    /// <summary>All holds of a student, open ones first, then the newest.</summary>
    Task<List<EnrollmentHoldDto>> GetByStudentAsync(Guid studentId);
    Task<EnrollmentHoldDto> AddAsync(Guid studentId, AddEnrollmentHoldDto dto, Guid actorId, int actorRole);
    Task<EnrollmentHoldDto> RemoveAsync(Guid holdId, RemoveEnrollmentHoldDto dto, Guid actorId, int actorRole);
}

public class EnrollmentHoldService : IEnrollmentHoldService
{
    private readonly AppDbContext _context;

    public EnrollmentHoldService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<EnrollmentHoldDto>> GetByStudentAsync(Guid studentId)
    {
        var holds = await _context.EnrollmentHolds.AsNoTracking()
            .Where(h => h.UserID == studentId)
            .ToListAsync();
        var names = await NamesAsync(holds.SelectMany(h => new[] { (Guid?)h.AddedByUserID, h.RemovedByUserID }));
        return holds
            .OrderBy(h => h.RemovedAt != null)
            .ThenByDescending(h => h.AddedAt)
            .Select(h => ToDto(h, names))
            .ToList();
    }

    /// <summary>
    /// Accounting may only raise or lift the one hold its office is responsible for. The role
    /// filter decides who may call this; this decides what they may say. Without it, an
    /// Accounting account could park an "Other" hold on a student for any reason at all, which
    /// is the Registrar's call and nobody else's.
    /// </summary>
    private static void GuardReason(int actorRole, string reason)
    {
        if (actorRole == RoleUtils.Accounting && reason != EnrollmentHoldReasons.UnpaidBalance)
        {
            throw new UnauthorizedAccessException(
                "The Accounting Office can only raise or lift an unpaid balance hold.");
        }
    }

    public async Task<EnrollmentHoldDto> AddAsync(Guid studentId, AddEnrollmentHoldDto dto, Guid actorId, int actorRole)
    {
        GuardReason(actorRole, dto.Reason);

        bool isStudent = await _context.Users.AnyAsync(u => u.UserID == studentId && u.Role == RoleUtils.Student);
        if (!isStudent) throw new KeyNotFoundException("Student not found.");

        if (await _context.EnrollmentHolds.AnyAsync(h => h.UserID == studentId && h.Reason == dto.Reason && h.RemovedAt == null))
        {
            throw new InvalidOperationException(
                $"This student already has an open \"{EnrollmentHoldReasons.Label(dto.Reason)}\" hold.");
        }

        var hold = new EnrollmentHold
        {
            HoldID = Guid.NewGuid(),
            UserID = studentId,
            Reason = dto.Reason,
            Note = Clean(dto.Note),
            AddedByUserID = actorId,
            AddedAt = DateTime.UtcNow,
        };
        _context.EnrollmentHolds.Add(hold);
        await _context.SaveChangesAsync();
        return ToDto(hold, await NamesAsync([actorId]));
    }

    public async Task<EnrollmentHoldDto> RemoveAsync(Guid holdId, RemoveEnrollmentHoldDto dto, Guid actorId, int actorRole)
    {
        var hold = await _context.EnrollmentHolds.FirstOrDefaultAsync(h => h.HoldID == holdId)
            ?? throw new KeyNotFoundException("Hold not found.");

        // Checked against the stored hold, not a caller-supplied reason: lifting is the side
        // that matters, since an unrestricted Accounting account could otherwise clear a
        // Registrar's hold and let a student straight through.
        GuardReason(actorRole, hold.Reason);

        if (!hold.IsOpen) throw new InvalidOperationException("This hold was already removed.");

        hold.RemovedByUserID = actorId;
        hold.RemovedAt = DateTime.UtcNow;
        hold.RemovalNote = Clean(dto.Note);
        await _context.SaveChangesAsync();
        return ToDto(hold, await NamesAsync([hold.AddedByUserID, actorId]));
    }

    private static string? Clean(string? note) => string.IsNullOrWhiteSpace(note) ? null : note.Trim();

    private async Task<Dictionary<Guid, string>> NamesAsync(IEnumerable<Guid?> ids)
    {
        var wanted = ids.Where(i => i.HasValue).Select(i => i!.Value).Distinct().ToList();
        return await _context.UserDetails.AsNoTracking()
            .Where(d => wanted.Contains(d.UserID))
            .ToDictionaryAsync(d => d.UserID, d => $"{d.Firstname} {d.Lastname}".Trim());
    }

    private static EnrollmentHoldDto ToDto(EnrollmentHold h, Dictionary<Guid, string> names) => new()
    {
        HoldId = h.HoldID,
        UserId = h.UserID,
        Reason = h.Reason,
        ReasonLabel = EnrollmentHoldReasons.Label(h.Reason),
        Note = h.Note,
        AddedAt = h.AddedAt,
        AddedByName = names.GetValueOrDefault(h.AddedByUserID),
        RemovedAt = h.RemovedAt,
        RemovedByName = h.RemovedByUserID is { } r ? names.GetValueOrDefault(r) : null,
        RemovalNote = h.RemovalNote,
        IsOpen = h.IsOpen,
    };
}
