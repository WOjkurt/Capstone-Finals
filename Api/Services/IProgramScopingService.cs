namespace Api.Services;

public interface IProgramScopingService
{
    Task<int?> GetProgramIdAsync(Guid userId);
    Task EnsureProgramHeadAccessAsync(Guid userId, int? targetProgramId, string resourceName);
}
