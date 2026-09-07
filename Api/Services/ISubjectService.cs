using Api.DTOs.Setup;

namespace Api.Services;

public interface ISubjectService
{
    Task<SubjectDto> CreateAsync(CreateSubjectDto dto);
    Task<List<SubjectDto>> GetAllAsync(int? programId = null, int? yearLevel = null);
    Task<SubjectDto?> GetByIdAsync(Guid subjectId);
    Task<SubjectDto> UpdateAsync(Guid subjectId, CreateSubjectDto dto);
    Task DeleteAsync(Guid subjectId);

    Task<PrerequisiteDto> AddPrerequisiteAsync(CreatePrerequisiteDto dto);
    Task RemovePrerequisiteAsync(Guid prerequisiteId);
    Task<List<PrerequisiteDto>> GetPrerequisitesForSubjectAsync(Guid subjectId);
}
