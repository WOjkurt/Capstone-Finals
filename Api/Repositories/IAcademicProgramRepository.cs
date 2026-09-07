using Api.Domain.Enrollment;

namespace Api.Repositories;

public interface IAcademicProgramRepository
{
    Task<AcademicProgram?> GetByIdAsync(int programId);
    Task<List<AcademicProgram>> GetAllAsync();
    Task AddAsync(AcademicProgram program);
    Task UpdateAsync(AcademicProgram program);
    Task DeleteAsync(int programId);
}
