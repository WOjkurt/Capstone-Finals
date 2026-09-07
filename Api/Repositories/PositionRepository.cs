using Api.Domain.IdentityAccess;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class PositionRepository : IPositionRepository
{
    private readonly AppDbContext _context;

    public PositionRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Position?> GetByIdAsync(Guid positionId)
    {
        return await _context.Positions.FindAsync(positionId);
    }

    public async Task<List<Position>> GetAllAsync()
    {
        return await _context.Positions.ToListAsync();
    }

    public async Task AddAsync(Position position)
    {
        await _context.Positions.AddAsync(position);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(Position position)
    {
        _context.Positions.Update(position);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid positionId)
    {
        var position = await _context.Positions.FindAsync(positionId);
        if (position != null)
        {
            _context.Positions.Remove(position);
            await _context.SaveChangesAsync();
        }
    }
}
