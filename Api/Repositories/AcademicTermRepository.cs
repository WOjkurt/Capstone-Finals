using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

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

        IDbContextTransaction? transaction = null;
        if (_context.Database.IsRelational())
        {
            transaction = await _context.Database.BeginTransactionAsync();
        }

        try
        {
            // Step 1: Deactivate any currently active term(s) first
            var currentlyActive = terms.Where(t => t.IsActive && t.TermID != termId).ToList();
            if (currentlyActive.Count > 0)
            {
                foreach (var term in currentlyActive)
                {
                    term.IsActive = false;
                }
                await _context.SaveChangesAsync();
            }

            // Step 2: Activate the target term
            if (!target.IsActive)
            {
                target.IsActive = true;
                await _context.SaveChangesAsync();
            }

            if (transaction != null)
            {
                await transaction.CommitAsync();
            }
        }
        finally
        {
            if (transaction != null)
            {
                await transaction.DisposeAsync();
            }
        }
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
