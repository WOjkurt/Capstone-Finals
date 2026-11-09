using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Curriculum;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface ICurriculumService
{
    Task<List<CurriculumDto>> GetAllAsync(int? programId);
    Task<CurriculumDto> CreateAsync(SaveCurriculumDto dto);
    Task<CurriculumDto> UpdateAsync(Guid curriculumId, SaveCurriculumDto dto);
    Task DeleteAsync(Guid curriculumId);

    /// <summary>The program's newest curriculum, made first if the program has none yet.</summary>
    Task<Guid> NewestOrCreateAsync(int programId);

    /// <summary>The curriculum of the batch that started in <paramref name="batchYear"/>, or null if the program has none.</summary>
    Task<Guid?> ForBatchAsync(int programId, int batchYear);

    /// <summary>Puts a student on another curriculum of their program. Returns the old and new names.</summary>
    Task<(string? OldName, string NewName)> SetStudentCurriculumAsync(Guid studentId, Guid curriculumId);

    Task<StudentCurriculumDto> GetStudentCurriculumAsync(Guid studentId);
}

public class CurriculumService : ICurriculumService
{
    /// <summary>Effective year of the curriculum made for programs that had subjects before curricula existed.</summary>
    public const int FirstCurriculumYear = 2000;

    private readonly AppDbContext _context;

    public CurriculumService(AppDbContext context)
    {
        _context = context;
    }

    /// <summary>"2026-2027" → 2026; null when it isn't a school year.</summary>
    public static int? StartYear(string? schoolYear)
    {
        if (string.IsNullOrWhiteSpace(schoolYear)) return null;
        var first = schoolYear.Trim().Split('-')[0].Trim();
        return int.TryParse(first, out var y) && y is >= 1900 and <= 2200 ? y : null;
    }

    /// <summary>The school year a student in <paramref name="yearLevel"/> started: a 2nd year in 2026-2027 started in 2025.</summary>
    public static int BatchYear(int termStartYear, int? yearLevel) => termStartYear - (Math.Max(1, yearLevel ?? 1) - 1);

    /// <summary>The newest curriculum that had taken effect by <paramref name="batchYear"/>; the oldest one if none had.</summary>
    public static Curriculum? ForBatch(IEnumerable<Curriculum> programCurricula, int batchYear)
    {
        var list = programCurricula.ToList();
        return list.Where(c => c.EffectiveFromYear <= batchYear).MaxBy(c => c.EffectiveFromYear)
            ?? list.MinBy(c => c.EffectiveFromYear);
    }

    public static string SchoolYearLabel(int startYear) => $"{startYear}-{startYear + 1}";

    public async Task<List<CurriculumDto>> GetAllAsync(int? programId)
    {
        var curricula = await _context.Curricula.AsNoTracking()
            .Include(c => c.Program)
            .Where(c => programId == null || c.ProgramID == programId)
            .ToListAsync();
        var ids = curricula.Select(c => c.CurriculumID).ToList();
        var subjectCounts = await _context.Subjects.AsNoTracking()
            .Where(s => ids.Contains(s.CurriculumID))
            .GroupBy(s => s.CurriculumID)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Key, x => x.Count);
        var studentCounts = await _context.UserDetails.AsNoTracking()
            .Where(u => u.CurriculumID != null && ids.Contains(u.CurriculumID.Value) &&
                        u.User != null && u.User.Role == RoleUtils.Student)
            .GroupBy(u => u.CurriculumID!.Value)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Key, x => x.Count);
        var newest = curricula.GroupBy(c => c.ProgramID)
            .Select(g => g.MaxBy(c => c.EffectiveFromYear)!.CurriculumID)
            .ToHashSet();

        return curricula
            .OrderBy(c => c.Program?.ProgramCode)
            .ThenByDescending(c => c.EffectiveFromYear)
            .Select(c => ToDto(c, subjectCounts.GetValueOrDefault(c.CurriculumID), studentCounts.GetValueOrDefault(c.CurriculumID),
                newest.Contains(c.CurriculumID)))
            .ToList();
    }

    public async Task<CurriculumDto> CreateAsync(SaveCurriculumDto dto)
    {
        var program = await _context.AcademicPrograms.AsNoTracking().FirstOrDefaultAsync(p => p.ProgramID == dto.ProgramID)
            ?? throw new KeyNotFoundException("Program not found.");
        var name = CleanName(dto.Name);
        await EnsureYearFreeAsync(dto.ProgramID, dto.EffectiveFromYear, null, program.ProgramCode);

        var curriculum = new Curriculum
        {
            CurriculumID = Guid.NewGuid(),
            ProgramID = dto.ProgramID,
            Name = name,
            EffectiveFromYear = dto.EffectiveFromYear,
            CreatedAt = DateTime.UtcNow,
        };
        _context.Curricula.Add(curriculum);
        await _context.SaveChangesAsync();
        return (await GetAllAsync(dto.ProgramID)).First(c => c.CurriculumID == curriculum.CurriculumID);
    }

    public async Task<CurriculumDto> UpdateAsync(Guid curriculumId, SaveCurriculumDto dto)
    {
        var curriculum = await _context.Curricula.Include(c => c.Program).FirstOrDefaultAsync(c => c.CurriculumID == curriculumId)
            ?? throw new KeyNotFoundException("Curriculum not found.");
        var name = CleanName(dto.Name);
        await EnsureYearFreeAsync(curriculum.ProgramID, dto.EffectiveFromYear, curriculumId, curriculum.Program?.ProgramCode);

        curriculum.Name = name;
        curriculum.EffectiveFromYear = dto.EffectiveFromYear;
        await _context.SaveChangesAsync();
        return (await GetAllAsync(curriculum.ProgramID)).First(c => c.CurriculumID == curriculumId);
    }

    public async Task DeleteAsync(Guid curriculumId)
    {
        var curriculum = await _context.Curricula.FirstOrDefaultAsync(c => c.CurriculumID == curriculumId)
            ?? throw new KeyNotFoundException("Curriculum not found.");
        if (await _context.Subjects.AnyAsync(s => s.CurriculumID == curriculumId))
        {
            throw new InvalidOperationException("This curriculum still has subjects. Delete or move them first.");
        }
        if (await _context.UserDetails.AnyAsync(u => u.CurriculumID == curriculumId))
        {
            throw new InvalidOperationException("Students are assigned to this curriculum. Move them to another curriculum first.");
        }
        _context.Curricula.Remove(curriculum);
        await _context.SaveChangesAsync();
    }

    public async Task<Guid> NewestOrCreateAsync(int programId)
    {
        var newest = await _context.Curricula.AsNoTracking()
            .Where(c => c.ProgramID == programId)
            .OrderByDescending(c => c.EffectiveFromYear)
            .Select(c => (Guid?)c.CurriculumID)
            .FirstOrDefaultAsync();
        if (newest is { } id) return id;

        var curriculum = new Curriculum
        {
            CurriculumID = Guid.NewGuid(),
            ProgramID = programId,
            Name = "First curriculum",
            EffectiveFromYear = FirstCurriculumYear,
            CreatedAt = DateTime.UtcNow,
        };
        _context.Curricula.Add(curriculum);

        // Like the migration: the program's first curriculum takes the subjects and students that have none yet.
        var orphanSubjects = await _context.Subjects
            .Where(s => s.ProgramID == programId && s.CurriculumID == Guid.Empty)
            .ToListAsync();
        foreach (var s in orphanSubjects) s.CurriculumID = curriculum.CurriculumID;
        var students = await _context.UserDetails
            .Where(u => u.ProgramID == programId && u.CurriculumID == null && u.User != null && u.User.Role == RoleUtils.Student)
            .ToListAsync();
        foreach (var u in students) u.CurriculumID = curriculum.CurriculumID;

        await _context.SaveChangesAsync();
        return curriculum.CurriculumID;
    }

    public async Task<Guid?> ForBatchAsync(int programId, int batchYear)
    {
        var curricula = await _context.Curricula.AsNoTracking().Where(c => c.ProgramID == programId).ToListAsync();
        return ForBatch(curricula, batchYear)?.CurriculumID;
    }

    public async Task<(string? OldName, string NewName)> SetStudentCurriculumAsync(Guid studentId, Guid curriculumId)
    {
        var student = await _context.UserDetails
            .Include(u => u.Curriculum)
            .FirstOrDefaultAsync(u => u.UserID == studentId && u.User != null && u.User.Role == RoleUtils.Student)
            ?? throw new KeyNotFoundException("Student not found.");
        var curriculum = await _context.Curricula.AsNoTracking().FirstOrDefaultAsync(c => c.CurriculumID == curriculumId)
            ?? throw new KeyNotFoundException("Curriculum not found.");
        if (student.ProgramID != curriculum.ProgramID)
        {
            throw new InvalidOperationException("That curriculum belongs to another program. Shift the student's program first.");
        }
        if (student.CurriculumID == curriculumId)
        {
            throw new InvalidOperationException($"The student already follows {curriculum.Name}.");
        }

        var oldName = student.Curriculum?.Name;
        student.CurriculumID = curriculumId;
        await _context.SaveChangesAsync();
        return (oldName, curriculum.Name);
    }

    public async Task<StudentCurriculumDto> GetStudentCurriculumAsync(Guid studentId)
    {
        var student = await _context.UserDetails.AsNoTracking()
            .Include(u => u.Curriculum)
            .FirstOrDefaultAsync(u => u.UserID == studentId && u.User != null && u.User.Role == RoleUtils.Student)
            ?? throw new KeyNotFoundException("Student not found.");
        return new StudentCurriculumDto
        {
            ProgramID = student.ProgramID,
            CurriculumID = student.CurriculumID,
            Name = student.Curriculum?.Name,
            EffectiveSchoolYear = student.Curriculum == null ? null : SchoolYearLabel(student.Curriculum.EffectiveFromYear),
        };
    }

    private static string CleanName(string? name)
    {
        var clean = (name ?? string.Empty).Trim();
        if (clean.Length == 0) throw new ArgumentException("Give the curriculum a name.");
        if (clean.Length > 100) throw new ArgumentException("The name can be at most 100 characters.");
        return clean;
    }

    private async Task EnsureYearFreeAsync(int programId, int year, Guid? exceptId, string? programCode)
    {
        if (year is < 1990 or > 2100)
        {
            throw new ArgumentException("The effective school year must start between 1990 and 2100.");
        }
        var taken = await _context.Curricula.AsNoTracking()
            .FirstOrDefaultAsync(c => c.ProgramID == programId && c.EffectiveFromYear == year && c.CurriculumID != exceptId);
        if (taken != null)
        {
            throw new InvalidOperationException(
                $"{programCode ?? "This program"} already has a curriculum for SY {SchoolYearLabel(year)}: {taken.Name}.");
        }
    }

    private static CurriculumDto ToDto(Curriculum c, int subjects, int students, bool isNewest) => new()
    {
        CurriculumID = c.CurriculumID,
        ProgramID = c.ProgramID,
        ProgramCode = c.Program?.ProgramCode,
        Name = c.Name,
        EffectiveFromYear = c.EffectiveFromYear,
        EffectiveSchoolYear = SchoolYearLabel(c.EffectiveFromYear),
        SubjectCount = subjects,
        StudentCount = students,
        IsNewest = isNewest,
    };
}

/// <summary>Picks the subjects a student follows: their curriculum, or the whole program for old records without one.</summary>
public static class StudentSubjects
{
    public static IQueryable<Subject> ForStudent(this IQueryable<Subject> subjects, UserDetails student)
    {
        int? programId = student.ProgramID;
        Guid? curriculumId = student.CurriculumID;
        return curriculumId is { } cid
            ? subjects.Where(s => s.ProgramID == programId && s.CurriculumID == cid)
            : subjects.Where(s => s.ProgramID == programId);
    }
}
