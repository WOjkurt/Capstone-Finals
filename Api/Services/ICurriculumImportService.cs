using Api.DTOs.Curriculum;

namespace Api.Services;

public interface ICurriculumImportService
{
    Task<CurriculumImportResponseDto> ImportAsync(
        Stream csvStream,
        string fileName,
        long fileLength,
        bool dryRun,
        bool updateExisting,
        Guid callerUserId,
        Guid? curriculumId = null);
}
