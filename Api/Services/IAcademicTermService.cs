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
    Task<AcademicTermDto> SetEnrollmentPeriodAsync(Guid termId, SetEnrollmentPeriodDto dto);
    Task DeleteAsync(Guid termId);
}
