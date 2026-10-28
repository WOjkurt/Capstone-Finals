using Api.DTOs.Class;

namespace Api.Services;

public interface IClassService
{
    Task<ClassDto> CreateAsync(CreateClassDto dto, Guid createdByUserId);
    Task<List<ClassDto>> GetAllAsync(Guid? termId = null, Guid? subjectId = null, Guid? teacherUserId = null, int? programId = null, Guid? studentUserId = null, int? yearLevel = null);
    Task<ClassDto?> GetByIdAsync(Guid classId);
    Task<bool> CanAccessClassAsync(Guid classId, Guid userId, int role);
    Task<ClassDto> UpdateAsync(Guid classId, UpdateClassDto dto);
    Task<ClassDto> AssignTeacherAsync(Guid classId, Guid? userId);
    Task DeleteAsync(Guid classId);
    Task<OpenTermResultDto> OpenTermAsync(OpenTermRequestDto request, bool dryRun, Guid callerUserId);
}
