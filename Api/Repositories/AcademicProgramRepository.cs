using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class AcademicProgramRepository : IAcademicProgramRepository
{
    private readonly AppDbContext _context;

    public AcademicProgramRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<AcademicProgram?> GetByIdAsync(int programId)
    {
        return await _context.AcademicPrograms.FindAsync(programId);
    }

    public async Task<List<AcademicProgram>> GetAllAsync()
    {
        return await _context.AcademicPrograms.ToListAsync();
    }

    public async Task AddAsync(AcademicProgram program)
    {
        await _context.AcademicPrograms.AddAsync(program);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(AcademicProgram program)
    {
        _context.AcademicPrograms.Update(program);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(int programId)
    {
        var program = await _context.AcademicPrograms.FindAsync(programId);
        if (program != null)
        {
            _context.AcademicPrograms.Remove(program);
            await _context.SaveChangesAsync();
        }
    }
}
