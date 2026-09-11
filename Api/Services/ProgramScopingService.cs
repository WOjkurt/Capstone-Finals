using Api.Repositories;

namespace Api.Services;

public class ProgramScopingService : IProgramScopingService
{
    private readonly IUserDetailsRepository _userDetailsRepository;

    public ProgramScopingService(IUserDetailsRepository userDetailsRepository)
    {
        _userDetailsRepository = userDetailsRepository;
    }

    public async Task<int?> GetProgramIdAsync(Guid userId)
    {
        var userDetails = await _userDetailsRepository.GetByUserIdAsync(userId);
        return userDetails?.ProgramID;
    }

    public async Task EnsureProgramHeadAccessAsync(Guid userId, int? targetProgramId, string resourceName)
    {
        var programId = await GetProgramIdAsync(userId);
        if (!programId.HasValue)
        {
            throw new UnauthorizedAccessException("Access denied. Your account is not assigned to an academic program.");
        }

        if (!targetProgramId.HasValue || targetProgramId.Value != programId.Value)
        {
            throw new UnauthorizedAccessException($"Access denied. This {resourceName} belongs to a different program.");
        }
    }
}
