using Api.Domain.Grading;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class GradeCorrectionRepository : IGradeCorrectionRepository
{
    private readonly AppDbContext _context;

    public GradeCorrectionRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<GradeCorrection?> GetByIdAsync(Guid correctionId)
    {
        return await _context.GradeCorrections
            .Include(gc => gc.Grade)
            .Include(gc => gc.RequestedByUser)
            .Include(gc => gc.ReviewedByUser)
            .FirstOrDefaultAsync(gc => gc.CorrectionID == correctionId);
    }

    public async Task<List<GradeCorrection>> GetByGradeIdAsync(Guid gradeId)
    {
        return await _context.GradeCorrections
            .Include(gc => gc.Grade)
            .Include(gc => gc.RequestedByUser)
            .Include(gc => gc.ReviewedByUser)
            .Where(gc => gc.GradeID == gradeId)
            .ToListAsync();
    }

    public async Task<List<GradeCorrection>> GetByStatusAsync(int status)
    {
        return await _context.GradeCorrections
            .Include(gc => gc.Grade)
            .Include(gc => gc.RequestedByUser)
            .Include(gc => gc.ReviewedByUser)
            .Where(gc => gc.CorrectionStatus == status)
            .ToListAsync();
    }

    public async Task<List<GradeCorrection>> GetAllAsync()
    {
        return await _context.GradeCorrections
            .Include(gc => gc.Grade)
            .Include(gc => gc.RequestedByUser)
            .Include(gc => gc.ReviewedByUser)
            .ToListAsync();
    }

    public async Task AddAsync(GradeCorrection correction)
    {
        await _context.GradeCorrections.AddAsync(correction);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(GradeCorrection correction)
    {
        _context.GradeCorrections.Update(correction);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid correctionId)
    {
        var correction = await _context.GradeCorrections.FindAsync(correctionId);
        if (correction != null)
        {
            _context.GradeCorrections.Remove(correction);
            await _context.SaveChangesAsync();
        }
    }
}
