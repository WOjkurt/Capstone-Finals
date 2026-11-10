using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Setup;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

// A program can have a major ("Major in Mechanical Technology"), like the registrar's own system.
public class ProgramMajorTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly AcademicProgramService _service;

    public ProgramMajorTests()
    {
        _context = new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        _service = new AcademicProgramService(_context, new AcademicProgramRepository(_context));
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    [Theory]
    [InlineData("Mechanical Technology", "Mechanical Technology")]
    [InlineData("  Major in Mechanical Technology ", "Mechanical Technology")]
    [InlineData("   ", null)]
    [InlineData(null, null)]
    public void CleanMajor_DropsTheWordsMajorIn(string? raw, string? expected)
    {
        Assert.Equal(expected, AcademicProgramService.CleanMajor(raw));
    }

    [Fact]
    public void FullName_AddsTheMajorOnlyWhenThereIsOne()
    {
        Assert.Equal("Bachelor of Technical-Vocational Teacher Education, Major in Mechanical Technology",
            AcademicProgram.FullNameOf("Bachelor of Technical-Vocational Teacher Education", "Mechanical Technology"));
        Assert.Equal("Bachelor of Science in Information Technology",
            AcademicProgram.FullNameOf("Bachelor of Science in Information Technology", null));
    }

    [Fact]
    public async Task CreateAndUpdate_SaveTheMajor()
    {
        var created = await _service.CreateAsync(new CreateAcademicProgramDto
        {
            ProgramCode = "BTVTED-MT", ProgramName = "Bachelor of Technical-Vocational Teacher Education", Major = "Major in Mechanical Technology"
        });
        Assert.Equal("Mechanical Technology", created.Major);
        Assert.Equal("Bachelor of Technical-Vocational Teacher Education, Major in Mechanical Technology", created.FullName);

        var updated = await _service.UpdateAsync(created.ProgramID, new CreateAcademicProgramDto
        {
            ProgramCode = "BTVTED-MT", ProgramName = "Bachelor of Technical-Vocational Teacher Education", Major = ""
        });
        Assert.Null(updated.Major);
        Assert.Null((await _service.GetAllAsync()).Single().Major);
    }

    [Fact]
    public async Task StudentEvaluation_ShowsTheProgramWithItsMajor()
    {
        _context.AcademicPrograms.Add(new AcademicProgram
        {
            ProgramID = 7, ProgramCode = "BTVTED-MT", ProgramName = "Bachelor of Technical-Vocational Teacher Education", Major = "Mechanical Technology"
        });
        var id = Guid.NewGuid();
        _context.Users.Add(new User { UserID = id, FirebaseUID = "f", Email = "s@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = id, Firstname = "A", Lastname = "B", ProgramID = 7, YearLevel = 1 });
        await _context.SaveChangesAsync();

        var evaluation = await new StudentRecordService(_context).GetEvaluationAsync(id);

        Assert.Equal("Bachelor of Technical-Vocational Teacher Education, Major in Mechanical Technology", evaluation.ProgramName);
    }
}
