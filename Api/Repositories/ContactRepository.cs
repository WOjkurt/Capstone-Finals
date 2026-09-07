using Api.Domain.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Repositories;

public class ContactRepository : IContactRepository
{
    private readonly AppDbContext _context;

    public ContactRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Contact?> GetByIdAsync(Guid contactId)
    {
        return await _context.Contacts
            .Include(c => c.EnrollmentForm)
            .FirstOrDefaultAsync(c => c.ContactID == contactId);
    }

    public async Task<List<Contact>> GetByEnrollmentIdAsync(Guid enrollmentId)
    {
        return await _context.Contacts
            .Include(c => c.EnrollmentForm)
            .Where(c => c.EnrollmentID == enrollmentId)
            .ToListAsync();
    }

    public async Task<List<Contact>> GetAllAsync()
    {
        return await _context.Contacts
            .Include(c => c.EnrollmentForm)
            .ToListAsync();
    }

    public async Task AddAsync(Contact contact)
    {
        await _context.Contacts.AddAsync(contact);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(Contact contact)
    {
        _context.Contacts.Update(contact);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid contactId)
    {
        var contact = await _context.Contacts.FindAsync(contactId);
        if (contact != null)
        {
            _context.Contacts.Remove(contact);
            await _context.SaveChangesAsync();
        }
    }
}
