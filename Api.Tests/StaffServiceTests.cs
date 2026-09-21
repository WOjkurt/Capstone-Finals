using Api.Auth;
using Api.Data;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Admin;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

public class TestAppDbContext : AppDbContext
{
    public TestAppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.Entity<EnrollmentResponse>().Ignore(e => e.Data);
    }
}

public class StaffServiceTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly Mock<IUserRepository> _userRepoMock;
    private readonly Mock<IUserDetailsRepository> _userDetailsRepoMock;
    private readonly Mock<IPositionRepository> _positionRepoMock;
    private readonly Mock<IAcademicProgramRepository> _programRepoMock;
    private readonly Mock<IConfiguration> _configMock;
    private readonly StaffService _service;

    public StaffServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _userRepoMock = new Mock<IUserRepository>();
        _userDetailsRepoMock = new Mock<IUserDetailsRepository>();
        _positionRepoMock = new Mock<IPositionRepository>();
        _programRepoMock = new Mock<IAcademicProgramRepository>();
        _configMock = new Mock<IConfiguration>();

        _service = new StaffService(
            _context,
            _userRepoMock.Object,
            _userDetailsRepoMock.Object,
            _positionRepoMock.Object,
            _programRepoMock.Object,
            _configMock.Object,
            NullLogger<StaffService>.Instance);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private async Task<(User user, UserDetails details)> SeedStaffAsync(
        int role,
        string email = "staff@dbtc-cebu.edu.ph",
        int? programId = null,
        string firstname = "John",
        string lastname = "Doe",
        Guid? specificUserId = null)
    {
        var userId = specificUserId ?? Guid.NewGuid();
        var user = new User
        {
            UserID = userId,
            FirebaseUID = $"fb_{userId}",
            Email = email,
            Role = role,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        var details = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = userId,
            Firstname = firstname,
            Lastname = lastname,
            ProgramID = programId,
            IsRegular = true
        };

        _context.Users.Add(user);
        _context.UserDetails.Add(details);
        await _context.SaveChangesAsync();

        _userRepoMock.Setup(r => r.GetByIdAsync(userId)).ReturnsAsync(user);
        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(userId)).ReturnsAsync(details);

        return (user, details);
    }

    [Fact]
    public async Task UpdateStaff_SuccessfulEdit_UpdatesFieldsAndReturnsDto()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var (user, details) = await SeedStaffAsync(RoleUtils.Teacher, programId: 1);

        _programRepoMock.Setup(r => r.GetByIdAsync(2))
            .ReturnsAsync(new AcademicProgram { ProgramID = 2, ProgramCode = "BSME", ProgramName = "Mechanical Engineering" });

        var dto = new UpdateStaffDto
        {
            Firstname = "Jane",
            Lastname = "Smith",
            EmployeeID = 4004,
            ProgramID = 2,
            IsRegular = false
        };

        // Act
        var result = await _service.UpdateStaffAsync(user.UserID, dto, adminId);

        // Assert
        Assert.NotNull(result);
        Assert.Equal("Jane", result.Firstname);
        Assert.Equal("Smith", result.Lastname);
        Assert.Equal(4004, result.EmployeeID);
        Assert.Equal(2, result.ProgramID);
        Assert.False(result.IsRegular);
        _userRepoMock.Verify(r => r.UpdateAsync(It.IsAny<User>()), Times.Once);
        _userDetailsRepoMock.Verify(r => r.UpdateAsync(It.IsAny<UserDetails>()), Times.Once);
    }

    [Fact]
    public async Task UpdateStaff_BlockedSelfRoleChange_ThrowsInvalidOperationException()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var (adminUser, _) = await SeedStaffAsync(RoleUtils.Admin, email: "admin@dbtc-cebu.edu.ph", specificUserId: adminId);

        var dto = new UpdateStaffDto
        {
            Role = RoleUtils.Registrar
        };

        // Act & Assert
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.UpdateStaffAsync(adminId, dto, adminId));

        Assert.Contains("You cannot change your own admin account role", ex.Message);
    }

    [Fact]
    public async Task UpdateStaff_BlockedAdminTargetEdit_ThrowsInvalidOperationException()
    {
        // Arrange
        var callerAdminId = Guid.NewGuid();
        var (targetAdmin, _) = await SeedStaffAsync(RoleUtils.Admin, email: "superadmin@dbtc-cebu.edu.ph");

        var dto = new UpdateStaffDto
        {
            Firstname = "UpdatedAdmin"
        };

        // Act & Assert
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.UpdateStaffAsync(targetAdmin.UserID, dto, callerAdminId));

        Assert.Contains("Admin accounts cannot be modified through staff management", ex.Message);
    }

    [Fact]
    public async Task UpdateStaff_ChangeToProgramHeadWithoutProgramId_ThrowsInvalidOperationException()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var (teacher, _) = await SeedStaffAsync(RoleUtils.Teacher, programId: null);

        var dto = new UpdateStaffDto
        {
            Role = RoleUtils.ProgramHead,
            ProgramID = null // Missing program
        };

        // Act & Assert
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.UpdateStaffAsync(teacher.UserID, dto, adminId));

        Assert.Contains("Academic program is required for Program Head", ex.Message);
    }

    [Fact]
    public async Task UpdateStaff_ChangeToRegistrar_ClearsProgramId()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var (programHead, _) = await SeedStaffAsync(RoleUtils.ProgramHead, programId: 1);

        var dto = new UpdateStaffDto
        {
            Role = RoleUtils.Registrar
        };

        // Act
        var result = await _service.UpdateStaffAsync(programHead.UserID, dto, adminId);

        // Assert
        Assert.Equal(RoleUtils.Registrar, result.Role);
        Assert.Null(result.ProgramID);
    }

    [Fact]
    public async Task UpdateStaff_DemoteProgramHeadToTeacher_PreservesProgramIdByDefault()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var (programHead, _) = await SeedStaffAsync(RoleUtils.ProgramHead, programId: 1);

        var dto = new UpdateStaffDto
        {
            Role = RoleUtils.Teacher,
            ProgramID = null // Omitted, should preserve existing programId (1)
        };

        // Act
        var result = await _service.UpdateStaffAsync(programHead.UserID, dto, adminId);

        // Assert
        Assert.Equal(RoleUtils.Teacher, result.Role);
        Assert.Equal(1, result.ProgramID);
    }

    [Fact]
    public async Task UpdateStaff_TeacherToRegistrarWithClasses_IncludesActiveClassesWarning()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var (teacher, _) = await SeedStaffAsync(RoleUtils.Teacher, programId: 1);

        // Add an assigned class for this teacher
        _context.Classes.Add(new Class
        {
            ClassID = Guid.NewGuid(),
            SubjectID = Guid.NewGuid(),
            UserID = teacher.UserID,
            TermID = Guid.NewGuid(),
            ClassName = "IT101 - Section A",
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        var dto = new UpdateStaffDto
        {
            Role = RoleUtils.Registrar
        };

        // Act
        var result = await _service.UpdateStaffAsync(teacher.UserID, dto, adminId);

        // Assert
        Assert.Equal(RoleUtils.Registrar, result.Role);
        Assert.NotNull(result.FirebaseSyncWarning);
        Assert.Contains("assigned as instructor to 1 class(es)", result.FirebaseSyncWarning);
        Assert.Contains("Reassign active offerings in Class Management", result.FirebaseSyncWarning);
    }
}
