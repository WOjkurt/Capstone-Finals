using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface IEnrollmentFormRepository
{
    Task<EnrollmentForm?> GetByIdAsync(Guid enrollmentId);
    Task<EnrollmentForm?> GetByApplicationIdAsync(Guid applicationId);
    Task<List<EnrollmentForm>> GetAllAsync();
    Task AddAsync(EnrollmentForm enrollmentForm);
    Task UpdateAsync(EnrollmentForm enrollmentForm);
    Task DeleteAsync(Guid enrollmentId);
}
