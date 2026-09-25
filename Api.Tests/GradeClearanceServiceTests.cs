using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

public class GradeClearanceServiceTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly GradeClearanceRepository _clearanceRepo;
    private readonly GradeClearanceService _service;

    public GradeClearanceServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _clearanceRepo = new GradeClearanceRepository(_context);
        _service = new GradeClearanceService(_context, _clearanceRepo);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    [Theory]
    [InlineData("Maria", "Santos", "maria.santos@dbtc-cebu.edu.ph", "Maria Santos")]
    [InlineData("  Maria  ", "  Santos  ", "maria.santos@dbtc-cebu.edu.ph", "Maria Santos")]
    public void FormatDisplayName_BothNamesPresent_ReturnsCombinedFullName(
        string firstname, string lastname, string email, string expected)
    {
        var result = GradeClearanceService.FormatDisplayName(firstname, lastname, email);
        Assert.Equal(expected, result);
    }

    [Theory]
    [InlineData("Maria", null, "maria@dbtc-cebu.edu.ph", "Maria")]
    [InlineData("Maria", "", "maria@dbtc-cebu.edu.ph", "Maria")]
    [InlineData("  Maria  ", "   ", "maria@dbtc-cebu.edu.ph", "Maria")]
    public void FormatDisplayName_OnlyFirstNamePresent_ReturnsFirstName(
        string firstname, string? lastname, string email, string expected)
    {
        var result = GradeClearanceService.FormatDisplayName(firstname, lastname, email);
        Assert.Equal(expected, result);
    }

    [Theory]
    [InlineData(null, "Santos", "santos@dbtc-cebu.edu.ph", "Santos")]
    [InlineData("", "Santos", "santos@dbtc-cebu.edu.ph", "Santos")]
    [InlineData("   ", "  Santos  ", "santos@dbtc-cebu.edu.ph", "Santos")]
    public void FormatDisplayName_OnlyLastNamePresent_ReturnsLastName(
        string? firstname, string lastname, string email, string expected)
    {
        var result = GradeClearanceService.FormatDisplayName(firstname, lastname, email);
        Assert.Equal(expected, result);
    }

    [Theory]
    [InlineData(null, null, "test.user@dbtc-cebu.edu.ph", "(no name on file) test.user@dbtc-cebu.edu.ph")]
    [InlineData("", "", "test.user@dbtc-cebu.edu.ph", "(no name on file) test.user@dbtc-cebu.edu.ph")]
    [InlineData("   ", "   ", "test.user@dbtc-cebu.edu.ph", "(no name on file) test.user@dbtc-cebu.edu.ph")]
    [InlineData("   ", "   ", "  test.user@dbtc-cebu.edu.ph  ", "(no name on file) test.user@dbtc-cebu.edu.ph")]
    public void FormatDisplayName_NeitherNamePresent_FallsBackToDistinguishableEmail(
        string? firstname, string? lastname, string email, string expected)
    {
        var result = GradeClearanceService.FormatDisplayName(firstname, lastname, email);
        Assert.Equal(expected, result);
    }

    [Theory]
    [InlineData(null, null, null)]
    [InlineData("", "", "")]
    [InlineData("   ", "   ", "   ")]
    public void FormatDisplayName_AllMissingOrEmpty_ReturnsNull(
        string? firstname, string? lastname, string? email)
    {
        var result = GradeClearanceService.FormatDisplayName(firstname, lastname, email);
        Assert.Null(result);
    }

    [Fact]
    public async Task GetByStudentAsync_ReviewerHasBothNames_SetsClearedByUserNameToFullName()
    {
        // Arrange
        var (studentId, termId, reviewerId) = await SeedBaseClearanceDataAsync();

        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = reviewerId,
            Firstname = "Maria Teresa",
            Lastname = "Gonzales"
        });
        await _context.SaveChangesAsync();

        // Act
        var results = await _service.GetByStudentAsync(studentId);

        // Assert
        Assert.Single(results);
        Assert.Equal("Maria Teresa Gonzales", results[0].ClearedByUserName);
    }

    [Fact]
    public async Task GetByStudentAsync_ReviewerHasOnlyFirstName_SetsClearedByUserNameToFirstName()
    {
        // Arrange
        var (studentId, termId, reviewerId) = await SeedBaseClearanceDataAsync();

        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = reviewerId,
            Firstname = "Cher",
            Lastname = ""
        });
        await _context.SaveChangesAsync();

        // Act
        var results = await _service.GetByStudentAsync(studentId);

        // Assert
        Assert.Single(results);
        Assert.Equal("Cher", results[0].ClearedByUserName);
    }

    [Fact]
    public async Task GetByStudentAsync_ReviewerHasOnlyLastName_SetsClearedByUserNameToLastName()
    {
        // Arrange
        var (studentId, termId, reviewerId) = await SeedBaseClearanceDataAsync();

        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = reviewerId,
            Firstname = "",
            Lastname = "Madonna"
        });
        await _context.SaveChangesAsync();

        // Act
        var results = await _service.GetByStudentAsync(studentId);

        // Assert
        Assert.Single(results);
        Assert.Equal("Madonna", results[0].ClearedByUserName);
    }

    [Fact]
    public async Task GetByStudentAsync_ReviewerHasBlankUserDetails_FallsBackToDistinguishableEmail()
    {
        // Arrange
        var (studentId, termId, reviewerId) = await SeedBaseClearanceDataAsync();

        // Reviewer exists in UserDetails but with blank names (like test fixtures)
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = reviewerId,
            Firstname = "  ",
            Lastname = "  "
        });
        await _context.SaveChangesAsync();

        // Act
        var results = await _service.GetByStudentAsync(studentId);

        // Assert
        Assert.Single(results);
        Assert.Equal("(no name on file) reviewer@dbtc-cebu.edu.ph", results[0].ClearedByUserName);
    }

    [Fact]
    public async Task GetByStudentAsync_ReviewerHasNoUserDetailsRecord_FallsBackToDistinguishableEmail()
    {
        // Arrange
        var (studentId, termId, reviewerId) = await SeedBaseClearanceDataAsync();

        // No UserDetails row seeded for reviewerId at all

        // Act
        var results = await _service.GetByStudentAsync(studentId);

        // Assert
        Assert.Single(results);
        Assert.Equal("(no name on file) reviewer@dbtc-cebu.edu.ph", results[0].ClearedByUserName);
    }

    [Fact]
    public async Task GetByStudentAsync_ReviewerMissingFromUsersAndUserDetails_SetsClearedByUserNameToNull()
    {
        // Arrange
        var studentId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        var nonExistentReviewerId = Guid.NewGuid();

        _context.Users.Add(new User
        {
            UserID = studentId,
            FirebaseUID = "fb-student",
            Email = "student@dbtc-cebu.edu.ph",
            Role = 5,
            IsActive = true
        });

        _context.AcademicTerms.Add(new AcademicTerm
        {
            TermID = termId,
            SchoolYear = "2025-2026",
            Semester = 1,
            IsActive = true
        });

        _context.GradeClearances.Add(new GradeClearance
        {
            ClearanceID = Guid.NewGuid(),
            UserID = studentId,
            TermID = termId,
            IsCleared = true,
            ClearedByUserID = nonExistentReviewerId,
            ClearedAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync();

        // Act
        var results = await _service.GetByStudentAsync(studentId);

        // Assert
        Assert.Single(results);
        Assert.Null(results[0].ClearedByUserName);
    }

    private async Task<(Guid studentId, Guid termId, Guid reviewerId)> SeedBaseClearanceDataAsync()
    {
        var studentId = Guid.NewGuid();
        var reviewerId = Guid.NewGuid();
        var termId = Guid.NewGuid();

        var student = new User
        {
            UserID = studentId,
            FirebaseUID = "fb-student-" + Guid.NewGuid(),
            Email = "student@dbtc-cebu.edu.ph",
            Role = 5,
            IsActive = true
        };

        var reviewer = new User
        {
            UserID = reviewerId,
            FirebaseUID = "fb-reviewer-" + Guid.NewGuid(),
            Email = "reviewer@dbtc-cebu.edu.ph",
            Role = 2,
            IsActive = true
        };

        var term = new AcademicTerm
        {
            TermID = termId,
            SchoolYear = "2025-2026",
            Semester = 1,
            IsActive = true
        };

        var clearance = new GradeClearance
        {
            ClearanceID = Guid.NewGuid(),
            UserID = studentId,
            TermID = termId,
            IsCleared = true,
            ClearedByUserID = reviewerId,
            ClearedAt = DateTime.UtcNow
        };

        _context.Users.AddRange(student, reviewer);
        _context.AcademicTerms.Add(term);
        _context.GradeClearances.Add(clearance);
        await _context.SaveChangesAsync();

        return (studentId, termId, reviewerId);
    }
}
