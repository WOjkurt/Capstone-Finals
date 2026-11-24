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
    /// <summary>
    /// Releases a term's grades to students, or withholds them again. Returns the term with the
    /// count of sheets nobody verified, so the Registrar is told what went out unchecked.
    /// </summary>
    Task<AcademicTermDto> SetGradesReleasedAsync(Guid termId, bool released, Guid callerId);

    Task DeleteAsync(Guid termId);
}
