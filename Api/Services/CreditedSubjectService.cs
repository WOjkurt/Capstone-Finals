using Api.Auth;
using Api.Domain.Enrollment;
using Api.DTOs.Credits;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface ICreditedSubjectService
{
    Task<List<CreditedSubjectDto>> GetByStudentAsync(Guid userId);
    Task<CreditedSubjectDto> CreateAsync(CreateCreditedSubjectDto dto, Guid recordedByUserId);
    Task DeleteAsync(Guid creditedSubjectId);
    Task<CreditedSubjectDto?> GetByIdAsync(Guid creditedSubjectId);
}

public class CreditedSubjectService : ICreditedSubjectService
{
    private readonly AppDbContext _context;

    public CreditedSubjectService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<CreditedSubjectDto>> GetByStudentAsync(Guid userId)
    {
        var credits = await _context.CreditedSubjects
            .AsNoTracking()
            .Include(c => c.Subject)
            .Where(c => c.UserID == userId)
            .ToListAsync();

        var result = new List<CreditedSubjectDto>();
        foreach (var c in credits.OrderBy(c => c.Subject?.YearLevel).ThenBy(c => c.Subject?.SubjectCode))
        {
            result.Add(await MapAsync(c, c.Subject));
        }
        return result;
    }

    public async Task<CreditedSubjectDto> CreateAsync(CreateCreditedSubjectDto dto, Guid recordedByUserId)
    {
        string school = dto.SourceSchool?.Trim() ?? string.Empty;
        if (school.Length == 0)
        {
            throw new InvalidOperationException("Enter the name of the school where the subject was taken.");
        }

        var student = await _context.UserDetails
            .AsNoTracking()
            .Include(ud => ud.User)
            .FirstOrDefaultAsync(ud => ud.UserID == dto.UserId);
        if (student == null || student.User?.Role != RoleUtils.Student)
        {
            throw new KeyNotFoundException("Student not found.");
        }

        var subject = await _context.Subjects.AsNoTracking().FirstOrDefaultAsync(s => s.SubjectID == dto.SubjectId)
            ?? throw new KeyNotFoundException("Subject not found.");

        if (!student.ProgramID.HasValue)
        {
            throw new InvalidOperationException("Set the student's program before crediting subjects.");
        }
        if (subject.ProgramID != student.ProgramID.Value)
        {
            throw new InvalidOperationException($"{subject.SubjectCode} is not in the student's program curriculum.");
        }

        if (await _context.CreditedSubjects.AnyAsync(c => c.UserID == dto.UserId && c.SubjectID == dto.SubjectId))
        {
            throw new InvalidOperationException($"{subject.SubjectCode} is already credited to this student.");
        }

        // A DBTC pass, or a DBTC load still in progress, takes precedence over a credit.
        // A subject failed at DBTC may still be credited (e.g. passed elsewhere in summer).
        var dbtcLoads = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.UserID == dto.UserId && sl.Class != null && sl.Class.SubjectID == dto.SubjectId &&
                         (sl.LoadStatus == StudyLoadStatus.Enrolled || sl.LoadStatus == StudyLoadStatus.Pending))
            .Select(sl => new { sl.StudyLoadID, sl.LoadStatus })
            .ToListAsync();
        var loadIds = dbtcLoads.Select(l => l.StudyLoadID).ToList();
        var remarks = await _context.Grades
            .AsNoTracking()
            .Where(g => loadIds.Contains(g.StudyLoadID))
            .ToDictionaryAsync(g => g.StudyLoadID, g => g.Remarks);

        if (dbtcLoads.Any(l => l.LoadStatus == StudyLoadStatus.Enrolled && remarks.GetValueOrDefault(l.StudyLoadID) == 1))
        {
            throw new InvalidOperationException($"The student already passed {subject.SubjectCode} at DBTC.");
        }
        if (dbtcLoads.Any(l => l.LoadStatus == StudyLoadStatus.Pending ||
                               remarks.GetValueOrDefault(l.StudyLoadID) is not (1 or 2)))
        {
            throw new InvalidOperationException(
                $"The student is currently taking {subject.SubjectCode} at DBTC (pending or not yet graded). Drop or reject that load before crediting it.");
        }

        var credit = new CreditedSubject
        {
            CreditedSubjectID = Guid.NewGuid(),
            UserID = dto.UserId,
            SubjectID = dto.SubjectId,
            SourceSchool = school,
            SourceSubjectCode = Blank(dto.SourceSubjectCode),
            Grade = Blank(dto.Grade),
            SchoolYear = Blank(dto.SchoolYear),
            RecordedByUserID = recordedByUserId,
            RecordedAt = DateTime.UtcNow
        };
        _context.CreditedSubjects.Add(credit);
        await _context.SaveChangesAsync();

        return await MapAsync(credit, subject);
    }

    public async Task<CreditedSubjectDto?> GetByIdAsync(Guid creditedSubjectId)
    {
        var c = await _context.CreditedSubjects.AsNoTracking().Include(x => x.Subject)
            .FirstOrDefaultAsync(x => x.CreditedSubjectID == creditedSubjectId);
        return c == null ? null : await MapAsync(c, c.Subject);
    }

    public async Task DeleteAsync(Guid creditedSubjectId)
    {
        var credit = await _context.CreditedSubjects.FirstOrDefaultAsync(c => c.CreditedSubjectID == creditedSubjectId)
            ?? throw new KeyNotFoundException("Credited subject not found.");
        _context.CreditedSubjects.Remove(credit);
        await _context.SaveChangesAsync();
    }

    private static string? Blank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

    private async Task<CreditedSubjectDto> MapAsync(CreditedSubject c, Subject? subject)
    {
        var recorder = await _context.UserDetails.AsNoTracking().FirstOrDefaultAsync(u => u.UserID == c.RecordedByUserID);
        return new CreditedSubjectDto
        {
            CreditedSubjectId = c.CreditedSubjectID,
            UserId = c.UserID,
            SubjectId = c.SubjectID,
            SubjectCode = subject?.SubjectCode ?? string.Empty,
            SubjectTitle = subject?.SubjectTitle ?? string.Empty,
            Units = (subject?.LecUnits ?? 0) + (subject?.LabUnits ?? 0),
            YearLevel = subject?.YearLevel ?? 0,
            SourceSchool = c.SourceSchool,
            SourceSubjectCode = c.SourceSubjectCode,
            Grade = c.Grade,
            SchoolYear = c.SchoolYear,
            RecordedBy = recorder != null ? $"{recorder.Firstname} {recorder.Lastname}".Trim() : null,
            RecordedAt = c.RecordedAt
        };
    }
}
