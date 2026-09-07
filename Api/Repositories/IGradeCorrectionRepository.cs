using Api.Domain.Grading;

namespace Api.Repositories;

public interface IGradeCorrectionRepository
{
    Task<GradeCorrection?> GetByIdAsync(Guid correctionId);
    Task<List<GradeCorrection>> GetByGradeIdAsync(Guid gradeId);
    Task<List<GradeCorrection>> GetByStatusAsync(int status);
    Task<List<GradeCorrection>> GetAllAsync();
    Task AddAsync(GradeCorrection correction);
    Task UpdateAsync(GradeCorrection correction);
    Task DeleteAsync(Guid correctionId);
}
