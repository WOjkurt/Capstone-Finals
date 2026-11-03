using System.Text;
using Api.Domain.Enrollment;
using Api.DTOs.Setup;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

// Setting Subject.IsMinor from the Registrar form and the curriculum CSV.
// Leaving the value out must never change an existing flag.
public class MinorSubjectFlagTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly SubjectService _subjectService;
    private readonly CurriculumImportService _importService;
    private readonly Guid _registrarId = Guid.NewGuid();

    private const string Header =
        "program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year";

    public MinorSubjectFlagTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _subjectService = new SubjectService(_context, new SubjectRepository(_context),
            new SubjectPrerequisiteRepository(_context), new AcademicProgramRepository(_context));
        _importService = new CurriculumImportService(_context);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private static MemoryStream Csv(string content) => new(Encoding.UTF8.GetBytes(content));

    private Task<Api.DTOs.Curriculum.CurriculumImportResponseDto> Import(string csv, bool updateExisting, bool dryRun = false)
    {
        var stream = Csv(csv);
        return _importService.ImportAsync(stream, "bsit.csv", stream.Length, dryRun, updateExisting, _registrarId);
    }

    private async Task<Subject> SeedSubject(string code, bool isMinor)
    {
        var s = new Subject
        {
            SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = "Title",
            LecUnits = 3, LabUnits = 0, LecHours = 3, LabHours = 0,
            ProgramID = 1, YearLevel = 1, DefaultSemester = 1, IsMinor = isMinor
        };
        _context.Subjects.Add(s);
        await _context.SaveChangesAsync();
        return s;
    }

    private static CreateSubjectDto Dto(string code, bool? isMinor) => new()
    {
        SubjectCode = code, SubjectTitle = "Title", LecUnits = 3, LabUnits = 0, LecHours = 3, LabHours = 0,
        ProgramID = 1, YearLevel = 1, DefaultSemester = 1, IsMinor = isMinor
    };

    private async Task<bool> IsMinor(string code) =>
        (await _context.Subjects.AsNoTracking().FirstAsync(s => s.SubjectCode == code)).IsMinor;

    // ── Registrar form (SubjectService) ──────────────────────────────

    [Fact]
    public async Task Create_WithoutIsMinor_IsMajor_AndWithTrue_IsMinor()
    {
        var major = await _subjectService.CreateAsync(Dto("IT 101", null));
        var minor = await _subjectService.CreateAsync(Dto("THEO 101", true));

        Assert.False(major.IsMinor);
        Assert.True(minor.IsMinor);
    }

    [Fact]
    public async Task Update_WithoutIsMinor_KeepsTheFlag()
    {
        var s = await SeedSubject("THEO 101", isMinor: true);

        var dto = Dto("THEO 101", null);
        dto.SubjectTitle = "Renamed";
        await _subjectService.UpdateAsync(s.SubjectID, dto);

        Assert.True(await IsMinor("THEO 101"));
    }

    [Fact]
    public async Task Update_WithIsMinor_ChangesTheFlagBothWays()
    {
        var s = await SeedSubject("MATH 105", isMinor: false);

        await _subjectService.UpdateAsync(s.SubjectID, Dto("MATH 105", true));
        Assert.True(await IsMinor("MATH 105"));

        await _subjectService.UpdateAsync(s.SubjectID, Dto("MATH 105", false));
        Assert.False(await IsMinor("MATH 105"));
    }

    // ── Curriculum CSV import ────────────────────────────────────────

    [Fact]
    public async Task Import_WithoutMinorColumn_UpdateMode_KeepsExistingMinorFlags()
    {
        await SeedSubject("THEO 101", isMinor: true);

        var result = await Import(Header + "\nBSIT,THEO 101,Title,3,3,0,3,0,1,1,,,\n", updateExisting: true);

        Assert.Equal(0, result.TotalErrors);
        Assert.Equal(1, result.Subjects.Unchanged);
        Assert.True(await IsMinor("THEO 101"));
    }

    [Fact]
    public async Task Import_WithMinorColumn_CreatesMinorAndMajor()
    {
        var csv = Header + ",minor\n" +
                  "BSIT,THEO 101,Title,3,3,0,3,0,1,1,,,,yes\n" +
                  "BSIT,GEC 101,Title,3,3,0,3,0,1,1,,,,Y\n" +
                  "BSIT,IT 101,Title,3,3,0,3,0,1,1,,,,no\n" +
                  "BSIT,IT 102,Title,3,3,0,3,0,1,1,,,,\n";

        var result = await Import(csv, updateExisting: false);

        Assert.Equal(0, result.TotalErrors);
        Assert.Equal(4, result.Subjects.Create);
        Assert.True(await IsMinor("THEO 101"));
        Assert.True(await IsMinor("GEC 101"));
        Assert.False(await IsMinor("IT 101"));
        Assert.False(await IsMinor("IT 102"));
    }

    [Fact]
    public async Task Import_MinorColumn_UpdateMode_ChangesFlagAndReportsIt()
    {
        await SeedSubject("MATH 105", isMinor: false);
        var csv = Header + ",minor\nBSIT,MATH 105,Title,3,3,0,3,0,1,1,,,,yes\n";

        var dry = await Import(csv, updateExisting: true, dryRun: true);
        Assert.Equal(1, dry.Subjects.Update);
        Assert.Contains(dry.Warnings, w => w.Message.Contains("IsMinor"));
        Assert.False(await IsMinor("MATH 105"));

        var applied = await Import(csv, updateExisting: true);
        Assert.Equal(0, applied.TotalErrors);
        Assert.True(await IsMinor("MATH 105"));
    }

    [Fact]
    public async Task Import_BadMinorValue_IsAnError_AndNothingIsSaved()
    {
        var csv = Header + ",minor\nBSIT,THEO 101,Title,3,3,0,3,0,1,1,,,,maybe\n";

        var result = await Import(csv, updateExisting: false);

        Assert.Equal(1, result.TotalErrors);
        Assert.Contains("minor must be yes, no or blank", result.Errors.Single().Message);
        Assert.Empty(await _context.Subjects.ToListAsync());
    }
}
