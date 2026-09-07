using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class EnrollmentApplicationRepository : IEnrollmentApplicationRepository
{
    private readonly AppDbContext _context;

    public EnrollmentApplicationRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<EnrollmentApplication?> GetByIdAsync(Guid applicationId)
    {
        return await _context.EnrollmentApplications
            .Include(ea => ea.Response)
            .Include(ea => ea.Program)
            .Include(ea => ea.Term)
            .Include(ea => ea.ReviewedByUser)
            .Include(ea => ea.StudentUser)
            .Include(ea => ea.CreatedByUser)
            .FirstOrDefaultAsync(ea => ea.ApplicationID == applicationId);
    }

    public async Task<List<EnrollmentApplication>> GetAllAsync()
    {
        return await _context.EnrollmentApplications
            .Include(ea => ea.Response)
            .Include(ea => ea.Program)
            .Include(ea => ea.Term)
            .Include(ea => ea.ReviewedByUser)
            .Include(ea => ea.StudentUser)
            .Include(ea => ea.CreatedByUser)
            .ToListAsync();
    }

    public async Task<List<EnrollmentApplication>> GetByStatusAsync(int status)
    {
        return await _context.EnrollmentApplications
            .Include(ea => ea.Response)
            .Include(ea => ea.Program)
            .Include(ea => ea.Term)
            .Include(ea => ea.ReviewedByUser)
            .Include(ea => ea.StudentUser)
            .Include(ea => ea.CreatedByUser)
            .Where(ea => ea.Status == status)
            .ToListAsync();
    }

    public async Task AddAsync(EnrollmentApplication application)
    {
        await _context.EnrollmentApplications.AddAsync(application);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(EnrollmentApplication application)
    {
        _context.EnrollmentApplications.Update(application);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid applicationId)
    {
        var application = await _context.EnrollmentApplications.FindAsync(applicationId);
        if (application != null)
        {
            _context.EnrollmentApplications.Remove(application);
            await _context.SaveChangesAsync();
        }
    }
}
