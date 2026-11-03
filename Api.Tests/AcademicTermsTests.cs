using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.DTOs.Setup;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

namespace Api.Tests;

public class AcademicTermsTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly AcademicTermRepository _termRepo;
    private readonly AcademicTermService _termService;

    public AcademicTermsTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _termRepo = new AcademicTermRepository(_context);
        _termService = new AcademicTermService(_context, _termRepo);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private AcademicTermsController CreateControllerWithUser(Guid userId, int role = RoleUtils.Admin)
    {
        var controller = new AcademicTermsController(_termService);
        var httpContext = new DefaultHttpContext();
        httpContext.Items["user_id"] = userId;
        httpContext.Items["role"] = role;
        controller.ControllerContext = new ControllerContext
        {
            HttpContext = httpContext
        };
        return controller;
    }

    [Fact]
    public async Task GetActive_WhenNoActiveTerm_ReturnsNotFound()
    {
        // Arrange
        var term1 = new AcademicTerm
        {
            TermID = Guid.NewGuid(),
            SchoolYear = "2024-2025",
            Semester = 1,
            IsActive = false
        };
        _context.AcademicTerms.Add(term1);
        await _context.SaveChangesAsync();

        var controller = CreateControllerWithUser(Guid.NewGuid());

        // Act
        var result = await controller.GetActive();

        // Assert
        var notFound = Assert.IsType<NotFoundObjectResult>(result);
        Assert.NotNull(notFound.Value);
    }

    [Fact]
    public async Task GetActive_WhenActiveTermExists_ReturnsOkWithTerm()
    {
        // Arrange
        var activeTermId = Guid.NewGuid();
        var term1 = new AcademicTerm
        {
            TermID = activeTermId,
            SchoolYear = "2025-2026",
            Semester = 1,
            IsActive = true
        };
        _context.AcademicTerms.Add(term1);
        await _context.SaveChangesAsync();

        var controller = CreateControllerWithUser(Guid.NewGuid());

        // Act
        var result = await controller.GetActive();

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var dto = Assert.IsType<AcademicTermDto>(okResult.Value);
        Assert.Equal(activeTermId, dto.TermID);
        Assert.True(dto.IsActive);
        Assert.Equal("2025-2026", dto.SchoolYear);
    }

    [Fact]
    public async Task ActivateTerm_DeactivatesPreviousActiveTerm_AndActivatesTarget()
    {
        // Arrange
        var term1 = new AcademicTerm
        {
            TermID = Guid.NewGuid(),
            SchoolYear = "2024-2025",
            Semester = 2,
            IsActive = true
        };
        var term2 = new AcademicTerm
        {
            TermID = Guid.NewGuid(),
            SchoolYear = "2025-2026",
            Semester = 1,
            IsActive = false
        };

        _context.AcademicTerms.AddRange(term1, term2);
        await _context.SaveChangesAsync();

        var controller = CreateControllerWithUser(Guid.NewGuid(), RoleUtils.Registrar);

        // Act - activate term2
        var result = await controller.Activate(term2.TermID);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var dto = Assert.IsType<AcademicTermDto>(okResult.Value);
        Assert.Equal(term2.TermID, dto.TermID);
        Assert.True(dto.IsActive);

        // Verify in database that term1 was deactivated and term2 is active
        var dbTerm1 = await _context.AcademicTerms.FindAsync(term1.TermID);
        var dbTerm2 = await _context.AcademicTerms.FindAsync(term2.TermID);

        Assert.NotNull(dbTerm1);
        Assert.NotNull(dbTerm2);
        Assert.False(dbTerm1.IsActive);
        Assert.True(dbTerm2.IsActive);
    }

    [Fact]
    public async Task ActivateTerm_NonExistentTerm_ReturnsNotFound()
    {
        // Arrange
        var controller = CreateControllerWithUser(Guid.NewGuid(), RoleUtils.Registrar);

        // Act
        var result = await controller.Activate(Guid.NewGuid());

        // Assert
        Assert.IsType<NotFoundObjectResult>(result);
    }

    [Fact]
    public async Task CreateTerm_DuplicateSchoolYearAndSemester_ReturnsBadRequest()
    {
        _context.AcademicTerms.Add(new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 1 });
        await _context.SaveChangesAsync();

        var controller = CreateControllerWithUser(Guid.NewGuid());
        var result = await controller.Create(new CreateAcademicTermDto { SchoolYear = " 2026-2027 ", Semester = 1 });

        Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(1, await _context.AcademicTerms.CountAsync());
    }

    [Fact]
    public async Task CreateTerm_SameSchoolYearDifferentSemester_ReturnsCreated()
    {
        _context.AcademicTerms.Add(new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 1 });
        await _context.SaveChangesAsync();

        var controller = CreateControllerWithUser(Guid.NewGuid());
        var result = await controller.Create(new CreateAcademicTermDto { SchoolYear = "2026-2027", Semester = 2 });

        Assert.IsType<CreatedAtActionResult>(result);
        Assert.Equal(2, await _context.AcademicTerms.CountAsync());
    }

    [Fact]
    public async Task UpdateTerm_ToExistingSchoolYearAndSemester_ReturnsBadRequest()
    {
        var existingId = Guid.NewGuid();
        var otherId = Guid.NewGuid();
        _context.AcademicTerms.AddRange(
            new AcademicTerm { TermID = existingId, SchoolYear = "2026-2027", Semester = 1 },
            new AcademicTerm { TermID = otherId, SchoolYear = "2026-2027", Semester = 2 });
        await _context.SaveChangesAsync();

        var controller = CreateControllerWithUser(Guid.NewGuid());
        var result = await controller.Update(otherId, new CreateAcademicTermDto { SchoolYear = "2026-2027", Semester = 1 });

        Assert.IsType<BadRequestObjectResult>(result);
        var other = await _context.AcademicTerms.AsNoTracking().FirstAsync(t => t.TermID == otherId);
        Assert.Equal(2, other.Semester);
    }

    [Fact]
    public async Task UpdateTerm_SavingSameValues_ReturnsOk()
    {
        var termId = Guid.NewGuid();
        _context.AcademicTerms.Add(new AcademicTerm { TermID = termId, SchoolYear = "2026-2027", Semester = 1 });
        await _context.SaveChangesAsync();

        var controller = CreateControllerWithUser(Guid.NewGuid());
        var result = await controller.Update(termId, new CreateAcademicTermDto { SchoolYear = "2026-2027", Semester = 1 });

        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task DeleteTerm_ReferencedByGradeClearance_ReturnsBadRequest()
    {
        var termId = Guid.NewGuid();
        _context.AcademicTerms.Add(new AcademicTerm { TermID = termId, SchoolYear = "2025-2026", Semester = 1 });
        _context.GradeClearances.Add(new Api.Domain.Grading.GradeClearance { ClearanceID = Guid.NewGuid(), UserID = Guid.NewGuid(), TermID = termId });
        await _context.SaveChangesAsync();

        var controller = CreateControllerWithUser(Guid.NewGuid());
        var result = await controller.Delete(termId);

        Assert.IsType<BadRequestObjectResult>(result);
        Assert.True(await _context.AcademicTerms.AnyAsync(t => t.TermID == termId));
    }

    [Fact]
    public async Task DeleteTerm_WithOverloadApproval_ReturnsBadRequest()
    {
        var termId = Guid.NewGuid();
        _context.AcademicTerms.Add(new AcademicTerm { TermID = termId, SchoolYear = "2025-2026", Semester = 2 });
        _context.OverloadApprovals.Add(new OverloadApproval
        {
            OverloadApprovalID = Guid.NewGuid(), UserID = Guid.NewGuid(), TermID = termId,
            Units = 24, MaxUnits = 21, Reason = "catching up", ApprovedByUserID = Guid.NewGuid(), ApprovedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        var result = await CreateControllerWithUser(Guid.NewGuid()).Delete(termId);

        var bad = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Contains("overload approvals", bad.Value!.ToString());
    }
}
