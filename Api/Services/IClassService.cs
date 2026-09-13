using Api.DTOs.Class;

namespace Api.Services;

public interface IClassService
{
    Task<ClassDto> CreateAsync(CreateClassDto dto, Guid createdByUserId);
    Task<List<ClassDto>> GetAllAsync(Guid? termId = null, Guid? subjectId = null, Guid? teacherUserId = null, int? programId = null);
    Task<ClassDto?> GetByIdAsync(Guid classId);
    Task<ClassDto> UpdateAsync(Guid classId, UpdateClassDto dto);
    Task<ClassDto> AssignTeacherAsync(Guid classId, Guid? userId);
    Task DeleteAsync(Guid classId);
}
