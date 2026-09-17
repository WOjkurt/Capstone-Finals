using Api.DTOs.Setup;

namespace Api.Services;

public interface IAcademicTermService
{
    Task<AcademicTermDto> CreateAsync(CreateAcademicTermDto dto);
    Task<List<AcademicTermDto>> GetAllAsync();
    Task<AcademicTermDto?> GetByIdAsync(Guid termId);
    Task<AcademicTermDto?> GetActiveAsync();
    Task<AcademicTermDto> UpdateAsync(Guid termId, CreateAcademicTermDto dto);
    Task<AcademicTermDto> ActivateAsync(Guid termId);
    Task DeleteAsync(Guid termId);
}
