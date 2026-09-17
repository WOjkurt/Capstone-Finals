using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class AcademicTermRepository : IAcademicTermRepository
{
    private readonly AppDbContext _context;

    public AcademicTermRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<AcademicTerm?> GetByIdAsync(Guid termId)
    {
        return await _context.AcademicTerms.FindAsync(termId);
    }

    public async Task<AcademicTerm?> GetActiveAsync()
    {
        return await _context.AcademicTerms.FirstOrDefaultAsync(t => t.IsActive);
    }

    public async Task<List<AcademicTerm>> GetAllAsync()
    {
        return await _context.AcademicTerms.ToListAsync();
    }

    public async Task SetActiveAsync(Guid termId)
    {
        var terms = await _context.AcademicTerms.ToListAsync();
        var target = terms.FirstOrDefault(t => t.TermID == termId);
        if (target == null)
        {
            throw new KeyNotFoundException($"AcademicTerm with ID '{termId}' was not found.");
        }

        foreach (var term in terms)
        {
            term.IsActive = (term.TermID == termId);
        }

        await _context.SaveChangesAsync();
    }

    public async Task AddAsync(AcademicTerm term)
    {
        await _context.AcademicTerms.AddAsync(term);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(AcademicTerm term)
    {
        _context.AcademicTerms.Update(term);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid termId)
    {
        var term = await _context.AcademicTerms.FindAsync(termId);
        if (term != null)
        {
            _context.AcademicTerms.Remove(term);
            await _context.SaveChangesAsync();
        }
    }
}
