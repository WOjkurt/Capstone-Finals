using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class SubjectPrerequisiteRepository : ISubjectPrerequisiteRepository
{
    private readonly AppDbContext _context;

    public SubjectPrerequisiteRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<SubjectPrerequisite?> GetByIdAsync(Guid prerequisiteId)
    {
        return await _context.SubjectPrerequisites
            .Include(sp => sp.Subject)
            .Include(sp => sp.PrerequisiteSubject)
            .FirstOrDefaultAsync(sp => sp.PrerequisiteID == prerequisiteId);
    }

    public async Task<List<SubjectPrerequisite>> GetBySubjectIdAsync(Guid subjectId)
    {
        return await _context.SubjectPrerequisites
            .Include(sp => sp.Subject)
            .Include(sp => sp.PrerequisiteSubject)
            .Where(sp => sp.SubjectID == subjectId)
            .ToListAsync();
    }

    public async Task<List<SubjectPrerequisite>> GetAllAsync()
    {
        return await _context.SubjectPrerequisites
            .Include(sp => sp.Subject)
            .Include(sp => sp.PrerequisiteSubject)
            .ToListAsync();
    }

    public async Task AddAsync(SubjectPrerequisite prerequisite)
    {
        await _context.SubjectPrerequisites.AddAsync(prerequisite);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(SubjectPrerequisite prerequisite)
    {
        _context.SubjectPrerequisites.Update(prerequisite);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid prerequisiteId)
    {
        var prerequisite = await _context.SubjectPrerequisites.FindAsync(prerequisiteId);
        if (prerequisite != null)
        {
            _context.SubjectPrerequisites.Remove(prerequisite);
            await _context.SaveChangesAsync();
        }
    }
}
