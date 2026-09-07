using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface IEnrollmentApplicationRepository
{
    Task<EnrollmentApplication?> GetByIdAsync(Guid applicationId);
    Task<List<EnrollmentApplication>> GetAllAsync();
    Task<List<EnrollmentApplication>> GetByStatusAsync(int status);
    Task AddAsync(EnrollmentApplication application);
    Task UpdateAsync(EnrollmentApplication application);
    Task DeleteAsync(Guid applicationId);
}
