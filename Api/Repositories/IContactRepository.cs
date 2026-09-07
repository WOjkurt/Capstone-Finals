using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface IContactRepository
{
    Task<Contact?> GetByIdAsync(Guid contactId);
    Task<List<Contact>> GetByEnrollmentIdAsync(Guid enrollmentId);
    Task<List<Contact>> GetAllAsync();
    Task AddAsync(Contact contact);
    Task UpdateAsync(Contact contact);
    Task DeleteAsync(Guid contactId);
}
