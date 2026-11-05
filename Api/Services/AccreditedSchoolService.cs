using Api.Domain.Enrollment;
using Api.DTOs.Credits;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface IAccreditedSchoolService
{
    Task<List<AccreditedSchoolDto>> GetAllAsync();
    Task<List<UnlistedSchoolDto>> GetUnlistedAsync();
    Task<AccreditedSchoolDto> CreateAsync(SaveAccreditedSchoolDto dto);
    Task<AccreditedSchoolDto> UpdateAsync(Guid id, SaveAccreditedSchoolDto dto);
    Task DeleteAsync(Guid id);
}

/// <summary>The accredited schools list. Names are unique ignoring case and extra spaces.</summary>
public class AccreditedSchoolService : IAccreditedSchoolService
{
    private readonly AppDbContext _context;

    public AccreditedSchoolService(AppDbContext context)
    {
        _context = context;
    }

    /// <summary>Trims and collapses inner spaces, so "Cebu  Normal University " matches "Cebu Normal University".</summary>
    public static string Normalize(string name) => string.Join(' ', name.Split(' ', StringSplitOptions.RemoveEmptyEntries));

    private static string Key(string name) => Normalize(name).ToUpperInvariant();

    private async Task<Dictionary<string, int>> CreditCountsAsync()
    {
        var names = await _context.CreditedSubjects.AsNoTracking().Select(c => c.SourceSchool).ToListAsync();
        return names.GroupBy(Key).ToDictionary(g => g.Key, g => g.Count());
    }

    public async Task<List<AccreditedSchoolDto>> GetAllAsync()
    {
        var counts = await CreditCountsAsync();
        var schools = await _context.AccreditedSchools.AsNoTracking().ToListAsync();
        return schools
            .OrderBy(s => s.Name)
            .Select(s => new AccreditedSchoolDto
            {
                SchoolId = s.SchoolID,
                Name = s.Name,
                Address = s.Address,
                CreditCount = counts.GetValueOrDefault(Key(s.Name))
            })
            .ToList();
    }

    /// <summary>Schools typed on credits before the list existed (or typed differently), so they can be added in one click.</summary>
    public async Task<List<UnlistedSchoolDto>> GetUnlistedAsync()
    {
        var listed = (await _context.AccreditedSchools.AsNoTracking().Select(s => s.Name).ToListAsync()).Select(Key).ToHashSet();
        var names = await _context.CreditedSubjects.AsNoTracking().Select(c => c.SourceSchool).ToListAsync();
        return names
            .GroupBy(Key)
            .Where(g => !listed.Contains(g.Key))
            .Select(g => new UnlistedSchoolDto { Name = Normalize(g.First()), CreditCount = g.Count() })
            .OrderBy(s => s.Name)
            .ToList();
    }

    private async Task EnsureUniqueAsync(string name, Guid? exceptId)
    {
        var key = Key(name);
        var others = await _context.AccreditedSchools.AsNoTracking()
            .Where(s => exceptId == null || s.SchoolID != exceptId)
            .Select(s => s.Name)
            .ToListAsync();
        if (others.Any(n => Key(n) == key))
        {
            throw new InvalidOperationException($"\"{Normalize(name)}\" is already on the list.");
        }
    }

    public async Task<AccreditedSchoolDto> CreateAsync(SaveAccreditedSchoolDto dto)
    {
        var name = Normalize(dto.Name);
        if (name.Length == 0) throw new InvalidOperationException("Enter the school's name.");
        await EnsureUniqueAsync(name, null);

        var school = new AccreditedSchool
        {
            SchoolID = Guid.NewGuid(),
            Name = name,
            Address = string.IsNullOrWhiteSpace(dto.Address) ? null : dto.Address.Trim(),
            CreatedAt = DateTime.UtcNow
        };
        _context.AccreditedSchools.Add(school);
        await _context.SaveChangesAsync();
        return (await GetAllAsync()).Single(s => s.SchoolId == school.SchoolID);
    }

    /// <summary>Renaming also renames the school on every credit that used the old name, so records stay consistent.</summary>
    public async Task<AccreditedSchoolDto> UpdateAsync(Guid id, SaveAccreditedSchoolDto dto)
    {
        var school = await _context.AccreditedSchools.FirstOrDefaultAsync(s => s.SchoolID == id)
            ?? throw new KeyNotFoundException("School not found.");
        var name = Normalize(dto.Name);
        if (name.Length == 0) throw new InvalidOperationException("Enter the school's name.");
        await EnsureUniqueAsync(name, id);

        if (name != school.Name)
        {
            var oldKey = Key(school.Name);
            var credits = (await _context.CreditedSubjects.ToListAsync()).Where(c => Key(c.SourceSchool) == oldKey);
            foreach (var c in credits)
            {
                c.SourceSchool = name;
            }
        }
        school.Name = name;
        school.Address = string.IsNullOrWhiteSpace(dto.Address) ? null : dto.Address.Trim();
        await _context.SaveChangesAsync();
        return (await GetAllAsync()).Single(s => s.SchoolId == id);
    }

    /// <summary>Removes the school from the list only; credits keep the name they were recorded with.</summary>
    public async Task DeleteAsync(Guid id)
    {
        var school = await _context.AccreditedSchools.FirstOrDefaultAsync(s => s.SchoolID == id)
            ?? throw new KeyNotFoundException("School not found.");
        _context.AccreditedSchools.Remove(school);
        await _context.SaveChangesAsync();
    }
}
