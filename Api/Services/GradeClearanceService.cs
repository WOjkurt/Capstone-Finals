using Api.Common;
using Api.Domain.Grading;
using Api.DTOs.Grading;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public class GradeClearanceService : IGradeClearanceService
{
    private readonly AppDbContext _context;
    private readonly IGradeClearanceRepository _clearanceRepository;

    public GradeClearanceService(AppDbContext context, IGradeClearanceRepository clearanceRepository)
    {
        _context = context;
        _clearanceRepository = clearanceRepository;
    }

    public async Task<GradeClearanceResponseDto> SetClearanceAsync(Guid userId, Guid termId, bool isCleared, Guid reviewerUserId)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null)
        {
            throw new KeyNotFoundException($"User with ID '{userId}' was not found.");
        }

        var term = await _context.AcademicTerms.FindAsync(termId);
        if (term == null)
        {
            throw new KeyNotFoundException($"AcademicTerm with ID '{termId}' was not found.");
        }

        var existing = await _clearanceRepository.GetByUserAndTermAsync(userId, termId);
        DateTime now = DateTime.UtcNow;

        GradeClearance clearance;
        if (existing != null)
        {
            existing.IsCleared = isCleared;
            existing.ClearedByUserID = reviewerUserId;
            existing.ClearedAt = now;
            await _clearanceRepository.UpdateAsync(existing);
            clearance = existing;
        }
        else
        {
            clearance = new GradeClearance
            {
                ClearanceID = Guid.NewGuid(),
                UserID = userId,
                TermID = termId,
                IsCleared = isCleared,
                ClearedByUserID = reviewerUserId,
                ClearedAt = now
            };
            await _clearanceRepository.AddAsync(clearance);
        }

        var updated = await _clearanceRepository.GetByUserAndTermAsync(userId, termId);
        return await MapToDtoAsync(updated ?? clearance);
    }

    public async Task<GradeClearanceResponseDto> CreateClearanceAsync(Guid userId, Guid termId, bool isCleared, Guid creatorUserId)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null)
        {
            throw new KeyNotFoundException($"User with ID '{userId}' was not found.");
        }

        var term = await _context.AcademicTerms.FindAsync(termId);
        if (term == null)
        {
            throw new KeyNotFoundException($"AcademicTerm with ID '{termId}' was not found.");
        }

        var existing = await _clearanceRepository.GetByUserAndTermAsync(userId, termId);
        if (existing != null)
        {
            throw new InvalidOperationException("A grade clearance record already exists for this student and academic term.");
        }

        DateTime? clearedAt = isCleared ? DateTime.UtcNow : null;
        Guid? clearedBy = isCleared ? creatorUserId : null;

        var clearance = new GradeClearance
        {
            ClearanceID = Guid.NewGuid(),
            UserID = userId,
            TermID = termId,
            IsCleared = isCleared,
            ClearedByUserID = clearedBy,
            ClearedAt = clearedAt
        };

        await _clearanceRepository.AddAsync(clearance);
        var created = await _clearanceRepository.GetByUserAndTermAsync(userId, termId);
        return await MapToDtoAsync(created ?? clearance);
    }

    public async Task EnsureClearanceAsync(Guid userId, Guid termId)
    {
        var existing = await _clearanceRepository.GetByUserAndTermAsync(userId, termId);
        if (existing == null)
        {
            var clearance = new GradeClearance
            {
                ClearanceID = Guid.NewGuid(),
                UserID = userId,
                TermID = termId,
                IsCleared = false, // safe default: hold / pending audit
                ClearedByUserID = null,
                ClearedAt = null
            };
            await _clearanceRepository.AddAsync(clearance);
        }
    }

    public async Task<bool> IsClearedAsync(Guid userId, Guid termId)
    {
        var clearance = await _clearanceRepository.GetByUserAndTermAsync(userId, termId);
        if (clearance == null)
        {
            return false;
        }

        return clearance.IsCleared;
    }

    public async Task<List<GradeClearanceResponseDto>> GetByStudentAsync(Guid userId)
    {
        var list = await _clearanceRepository.GetByUserAsync(userId);
        var result = new List<GradeClearanceResponseDto>();

        foreach (var item in list)
        {
            result.Add(await MapToDtoAsync(item));
        }

        return result;
    }

    private async Task<GradeClearanceResponseDto> MapToDtoAsync(GradeClearance gc)
    {
        string? termLabel = null;
        if (gc.Term != null)
        {
            termLabel = TermLabel.Format(gc.Term.SchoolYear, gc.Term.Semester);
        }
        else
        {
            var term = await _context.AcademicTerms.AsNoTracking().FirstOrDefaultAsync(t => t.TermID == gc.TermID);
            if (term != null)
            {
                termLabel = TermLabel.Format(term.SchoolYear, term.Semester);
            }
        }

        string? reviewerName = gc.ClearedByUserID.HasValue
            ? await ResolveUserNameAsync(gc.ClearedByUserID.Value)
            : null;

        return new GradeClearanceResponseDto
        {
            ClearanceID = gc.ClearanceID,
            UserID = gc.UserID,
            TermID = gc.TermID,
            TermLabel = termLabel,
            IsCleared = gc.IsCleared,
            ClearedByUserID = gc.ClearedByUserID,
            ClearedByUserName = reviewerName,
            ClearedAt = gc.ClearedAt
        };
    }

    public static string? FormatDisplayName(string? firstname, string? lastname, string? email)
    {
        bool hasFirst = !string.IsNullOrWhiteSpace(firstname);
        bool hasLast = !string.IsNullOrWhiteSpace(lastname);

        if (hasFirst && hasLast)
        {
            return $"{firstname!.Trim()} {lastname!.Trim()}";
        }

        if (hasFirst)
        {
            return firstname!.Trim();
        }

        if (hasLast)
        {
            return lastname!.Trim();
        }

        if (!string.IsNullOrWhiteSpace(email))
        {
            return $"(no name on file) {email.Trim()}";
        }

        return null;
    }

    private async Task<string?> ResolveUserNameAsync(Guid userId)
    {
        var userDetails = await _context.UserDetails
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.UserID == userId);

        bool hasFirst = userDetails != null && !string.IsNullOrWhiteSpace(userDetails.Firstname);
        bool hasLast = userDetails != null && !string.IsNullOrWhiteSpace(userDetails.Lastname);

        if (hasFirst || hasLast)
        {
            return FormatDisplayName(userDetails?.Firstname, userDetails?.Lastname, null);
        }

        var user = await _context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.UserID == userId);

        return FormatDisplayName(null, null, user?.Email);
    }
}
