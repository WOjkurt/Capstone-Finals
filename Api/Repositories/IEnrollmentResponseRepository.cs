using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface IEnrollmentResponseRepository
{
    Task<EnrollmentResponse?> GetByIdAsync(Guid responseId);
    Task<List<EnrollmentResponse>> GetAllAsync();
    Task<List<EnrollmentResponse>> GetUnprocessedAsync();
    Task AddAsync(EnrollmentResponse response);
    Task UpdateAsync(EnrollmentResponse response);
    Task DeleteAsync(Guid responseId);
}
