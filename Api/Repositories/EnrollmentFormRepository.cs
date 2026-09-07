using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class EnrollmentFormRepository : IEnrollmentFormRepository
{
    private readonly AppDbContext _context;

    public EnrollmentFormRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<EnrollmentForm?> GetByIdAsync(Guid enrollmentId)
    {
        return await _context.EnrollmentForms
            .Include(ef => ef.Application)
            .FirstOrDefaultAsync(ef => ef.EnrollmentID == enrollmentId);
    }

    public async Task<EnrollmentForm?> GetByApplicationIdAsync(Guid applicationId)
    {
        return await _context.EnrollmentForms
            .Include(ef => ef.Application)
            .FirstOrDefaultAsync(ef => ef.ApplicationID == applicationId);
    }

    public async Task<List<EnrollmentForm>> GetAllAsync()
    {
        return await _context.EnrollmentForms
            .Include(ef => ef.Application)
            .ToListAsync();
    }

    public async Task AddAsync(EnrollmentForm enrollmentForm)
    {
        await _context.EnrollmentForms.AddAsync(enrollmentForm);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(EnrollmentForm enrollmentForm)
    {
        _context.EnrollmentForms.Update(enrollmentForm);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid enrollmentId)
    {
        var enrollmentForm = await _context.EnrollmentForms.FindAsync(enrollmentId);
        if (enrollmentForm != null)
        {
            _context.EnrollmentForms.Remove(enrollmentForm);
            await _context.SaveChangesAsync();
        }
    }
}
