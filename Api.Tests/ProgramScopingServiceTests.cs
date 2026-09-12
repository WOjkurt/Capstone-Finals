using Api.Domain.IdentityAccess;
using Api.Repositories;
using Api.Services;
using Moq;
using Xunit;

namespace Api.Tests;

public class ProgramScopingServiceTests
{
    private readonly Mock<IUserDetailsRepository> _userDetailsRepoMock;
    private readonly ProgramScopingService _service;

    public ProgramScopingServiceTests()
    {
        _userDetailsRepoMock = new Mock<IUserDetailsRepository>();
        _service = new ProgramScopingService(_userDetailsRepoMock.Object);
    }

    [Fact]
    public async Task EnsureProgramHeadAccess_WhenTargetMatchesProgram_DoesNotThrow()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        int bsitProgramId = 1;
        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(programHeadId))
            .ReturnsAsync(new UserDetails
            {
                UserID = programHeadId,
                ProgramID = bsitProgramId,
                Firstname = "Program",
                Lastname = "Head"
            });

        // Act & Assert (Should not throw)
        await _service.EnsureProgramHeadAccessAsync(programHeadId, bsitProgramId, "class");
    }

    [Fact]
    public async Task EnsureProgramHeadAccess_WhenTargetBelongsToDifferentProgram_ThrowsUnauthorizedAccessException()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        int bsitProgramId = 1;
        int bsbaProgramId = 2;
        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(programHeadId))
            .ReturnsAsync(new UserDetails
            {
                UserID = programHeadId,
                ProgramID = bsitProgramId,
                Firstname = "Program",
                Lastname = "Head"
            });

        // Act & Assert
        var ex = await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            _service.EnsureProgramHeadAccessAsync(programHeadId, bsbaProgramId, "class"));

        Assert.Contains("belongs to a different program", ex.Message);
    }

    [Fact]
    public async Task EnsureProgramHeadAccess_WhenProgramHeadHasNoProgramAssigned_ThrowsUnauthorizedAccessException()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(programHeadId))
            .ReturnsAsync(new UserDetails
            {
                UserID = programHeadId,
                ProgramID = null,
                Firstname = "Unassigned",
                Lastname = "Head"
            });

        // Act & Assert
        var ex = await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            _service.EnsureProgramHeadAccessAsync(programHeadId, 1, "subject"));

        Assert.Contains("Your account is not assigned to an academic program.", ex.Message);
    }

    [Fact]
    public async Task EnsureProgramHeadAccess_ForTestProgramHeadProductionAccount_PermitsBSITAccess()
    {
        // Simulating test.programhead@dbtc-cebu.edu.ph with ProgramID = 1 (BSIT)
        var testProgramHeadId = Guid.Parse("00000000-0000-0000-0000-000000000001");
        int bsitProgramId = 1;
        int otherProgramId = 2;

        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(testProgramHeadId))
            .ReturnsAsync(new UserDetails
            {
                UserID = testProgramHeadId,
                ProgramID = bsitProgramId,
                Firstname = "Test",
                Lastname = "ProgramHead"
            });

        // Permitted on BSIT
        await _service.EnsureProgramHeadAccessAsync(testProgramHeadId, bsitProgramId, "class");

        // Forbidden on other program
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            _service.EnsureProgramHeadAccessAsync(testProgramHeadId, otherProgramId, "class"));
    }
}
