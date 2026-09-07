using Api.DTOs.Setup;

namespace Api.Services;

public interface IAcademicProgramService
{
    Task<AcademicProgramDto> CreateAsync(CreateAcademicProgramDto dto);
    Task<List<AcademicProgramDto>> GetAllAsync();
    Task<AcademicProgramDto?> GetByIdAsync(int programId);
    Task<AcademicProgramDto> UpdateAsync(int programId, CreateAcademicProgramDto dto);
    Task DeleteAsync(int programId);
}
