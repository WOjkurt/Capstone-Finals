using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class EnrollmentResponseRepository : IEnrollmentResponseRepository
{
    private readonly AppDbContext _context;

    public EnrollmentResponseRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<EnrollmentResponse?> GetByIdAsync(Guid responseId)
    {
        return await _context.EnrollmentResponses.FindAsync(responseId);
    }

    public async Task<List<EnrollmentResponse>> GetAllAsync()
    {
        return await _context.EnrollmentResponses.ToListAsync();
    }

    public async Task<List<EnrollmentResponse>> GetUnprocessedAsync()
    {
        return await _context.EnrollmentResponses
            .Where(r => !r.IsProcessed)
            .ToListAsync();
    }

    public async Task AddAsync(EnrollmentResponse response)
    {
        await _context.EnrollmentResponses.AddAsync(response);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(EnrollmentResponse response)
    {
        _context.EnrollmentResponses.Update(response);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid responseId)
    {
        var response = await _context.EnrollmentResponses.FindAsync(responseId);
        if (response != null)
        {
            _context.EnrollmentResponses.Remove(response);
            await _context.SaveChangesAsync();
        }
    }
}
