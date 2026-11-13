using Api.Domain.Enrollment;
using Api.DTOs.Setup;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface ISchoolSettingsService
{
    Task<UnitLimitSettingsDto> GetUnitLimitsAsync();
    Task<UnitLimitSettingsDto> SaveUnitLimitsAsync(SaveUnitLimitSettingsDto dto, Guid updatedBy);
    Task<DeansListRulesDto> GetDeansListRulesAsync();
    Task<DeansListRulesDto> SaveDeansListRulesAsync(SaveDeansListRulesDto dto, Guid updatedBy);
}

/// <summary>School-wide settings the Registrar can change, such as the summer unit limits.</summary>
public class SchoolSettingsService : ISchoolSettingsService
{
    private const decimal HighestLimit = 30m;

    /// <summary>DBTC's Dean's list rules (Registrar, 2026-11-13): past dean's listers never went over 1.7,
    /// and no subject grade went below 2.3.</summary>
    public const decimal DefaultDeansListMaxGwa = 1.7m;
    public const decimal DefaultDeansListWorstGrade = 2.3m;

    private readonly AppDbContext _context;

    public SchoolSettingsService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<UnitLimitSettingsDto> GetUnitLimitsAsync()
    {
        var saved = await _context.SchoolSettings.AsNoTracking().FirstOrDefaultAsync();
        if (saved == null)
        {
            return new UnitLimitSettingsDto
            {
                SummerMaxUnits = StudyLoadService.SummerMaxUnits,
                GraduatingSummerMaxUnits = StudyLoadService.GraduatingSummerMaxUnits
            };
        }
        var who = saved.UpdatedByUserID == null ? null : await _context.UserDetails.AsNoTracking()
            .Where(u => u.UserID == saved.UpdatedByUserID)
            .Select(u => u.Firstname + " " + u.Lastname)
            .FirstOrDefaultAsync();
        return new UnitLimitSettingsDto
        {
            SummerMaxUnits = saved.SummerMaxUnits,
            GraduatingSummerMaxUnits = saved.GraduatingSummerMaxUnits,
            UpdatedBy = who,
            UpdatedAt = saved.UpdatedAt
        };
    }

    public async Task<DeansListRulesDto> GetDeansListRulesAsync()
    {
        var saved = await _context.SchoolSettings.AsNoTracking().FirstOrDefaultAsync();
        var dto = new DeansListRulesDto
        {
            MaxGwa = saved?.DeansListMaxGwa ?? DefaultDeansListMaxGwa,
            WorstGrade = saved?.DeansListWorstGrade ?? DefaultDeansListWorstGrade,
        };
        if (saved?.DeansListMaxGwa != null)
        {
            dto.UpdatedAt = saved.UpdatedAt;
            dto.UpdatedBy = saved.UpdatedByUserID == null ? null : await _context.UserDetails.AsNoTracking()
                .Where(u => u.UserID == saved.UpdatedByUserID)
                .Select(u => u.Firstname + " " + u.Lastname)
                .FirstOrDefaultAsync();
        }
        return dto;
    }

    public async Task<DeansListRulesDto> SaveDeansListRulesAsync(SaveDeansListRulesDto dto, Guid updatedBy)
    {
        if (dto.MaxGwa is < 1m or > 3m || dto.WorstGrade is < 1m or > 3m)
        {
            throw new InvalidOperationException("Enter grades between 1.0 and 3.0.");
        }
        if (dto.WorstGrade < dto.MaxGwa)
        {
            throw new InvalidOperationException("The lowest allowed grade can't be better than the GWA cutoff.");
        }
        var saved = await _context.SchoolSettings.FirstOrDefaultAsync();
        if (saved == null)
        {
            saved = new SchoolSettings
            {
                SummerMaxUnits = StudyLoadService.SummerMaxUnits,
                GraduatingSummerMaxUnits = StudyLoadService.GraduatingSummerMaxUnits,
            };
            _context.SchoolSettings.Add(saved);
        }
        saved.DeansListMaxGwa = dto.MaxGwa;
        saved.DeansListWorstGrade = dto.WorstGrade;
        saved.UpdatedByUserID = updatedBy;
        saved.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return await GetDeansListRulesAsync();
    }

    public async Task<UnitLimitSettingsDto> SaveUnitLimitsAsync(SaveUnitLimitSettingsDto dto, Guid updatedBy)
    {
        if (dto.SummerMaxUnits <= 0 || dto.GraduatingSummerMaxUnits <= 0 ||
            dto.SummerMaxUnits > HighestLimit || dto.GraduatingSummerMaxUnits > HighestLimit)
        {
            throw new InvalidOperationException($"Enter a limit between 1 and {HighestLimit:0} units.");
        }
        if (dto.GraduatingSummerMaxUnits < dto.SummerMaxUnits)
        {
            throw new InvalidOperationException("The limit for graduating students cannot be lower than the regular summer limit.");
        }

        var saved = await _context.SchoolSettings.FirstOrDefaultAsync();
        if (saved == null)
        {
            saved = new SchoolSettings();
            _context.SchoolSettings.Add(saved);
        }
        saved.SummerMaxUnits = dto.SummerMaxUnits;
        saved.GraduatingSummerMaxUnits = dto.GraduatingSummerMaxUnits;
        saved.UpdatedByUserID = updatedBy;
        saved.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return await GetUnitLimitsAsync();
    }
}
