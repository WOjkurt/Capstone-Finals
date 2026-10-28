using Api.Auth;
using Api.Common;
using Api.Controllers;
using Api.Data;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Class;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;
using Xunit.Abstractions;

namespace Api.Tests;

// ─────────────────────────────────────────────────────────────────────────────
// Stage 6A – Bulk Open-Term Tests
// ─────────────────────────────────────────────────────────────────────────────

public class OpenTermServiceTests : IDisposable
{
    // ── In-memory DB helpers ──────────────────────────────────────────────────

    private static AppDbContext CreateDb()
    {
        var opts = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new TestAppDbContext(opts);
    }

    private static ClassService CreateService(AppDbContext db)
    {
        var classRepo = new Mock<IClassRepository>();
        var schedRepo = new Mock<IClassScheduleRepository>();
        return new ClassService(db, classRepo.Object, schedRepo.Object,
            NullLogger<ClassService>.Instance);
    }

    private readonly AppDbContext _db;
    private readonly ClassService _svc;
    private readonly ITestOutputHelper _output;

    public OpenTermServiceTests(ITestOutputHelper output)
    {
        _output = output;
        _db = CreateDb();
        _svc = CreateService(_db);
        SeedData();
    }

    // ── Seed ──────────────────────────────────────────────────────────────────

    private readonly int _programId = 1;
    private readonly Guid _termId1st = Guid.NewGuid(); // Semester 1
    private readonly Guid _termSummer = Guid.NewGuid(); // Semester 3 (summer)
    private readonly Guid _callerUserId = Guid.NewGuid();

    private void SeedData()
    {
        _db.AcademicPrograms.Add(new AcademicProgram
        {
            ProgramID = _programId,
            ProgramCode = "BSIT",
            ProgramName = "Bachelor of Science in Information Technology"
        });

        _db.AcademicTerms.Add(new AcademicTerm
        {
            TermID = _termId1st,
            SchoolYear = "2026-2027",
            Semester = 1,
            IsActive = true
        });

        _db.AcademicTerms.Add(new AcademicTerm
        {
            TermID = _termSummer,
            SchoolYear = "2026-2027",
            Semester = 3,
            IsActive = false
        });

        // Year 1 subjects: 2 in Semester 1, 1 with no semester
        _db.Subjects.Add(new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT 101", SubjectTitle = "Intro IT", ProgramID = _programId, YearLevel = 1, DefaultSemester = 1, LecUnits = 3, LabUnits = 0, LecHours = 3, LabHours = 0 });
        _db.Subjects.Add(new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT 102", SubjectTitle = "Math IT", ProgramID = _programId, YearLevel = 1, DefaultSemester = 1, LecUnits = 3, LabUnits = 0, LecHours = 3, LabHours = 0 });
        _db.Subjects.Add(new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT 103", SubjectTitle = "PE 1", ProgramID = _programId, YearLevel = 1, DefaultSemester = 0, LecUnits = 2, LabUnits = 0, LecHours = 2, LabHours = 0 });

        // Year 2 subject in Semester 2 (should not appear for Semester 1 term)
        _db.Subjects.Add(new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT 201", SubjectTitle = "Data Structures", ProgramID = _programId, YearLevel = 2, DefaultSemester = 2, LecUnits = 3, LabUnits = 0, LecHours = 3, LabHours = 0 });

        // Year 3 subject in Semester 1
        _db.Subjects.Add(new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT 301", SubjectTitle = "Web Dev", ProgramID = _programId, YearLevel = 3, DefaultSemester = 1, LecUnits = 3, LabUnits = 0, LecHours = 3, LabHours = 0 });

        // Summer subject
        _db.Subjects.Add(new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT 401", SubjectTitle = "OJT", ProgramID = _programId, YearLevel = 4, DefaultSemester = 3, LecUnits = 0, LabUnits = 0, LecHours = 0, LabHours = 0 });

        _db.SaveChanges();
    }

    public void Dispose() => _db.Dispose();

    // ── Tests ─────────────────────────────────────────────────────────────────

    [Fact]
    public async Task DryRun_WritesNothingToDatabase()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, Sections = 1 };

        var result = await _svc.OpenTermAsync(req, dryRun: true, _callerUserId);

        var jsonReq = System.Text.Json.JsonSerializer.Serialize(req, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
        var jsonRes = System.Text.Json.JsonSerializer.Serialize(result, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
        _output.WriteLine($"DRY_RUN_REQUEST:\n{jsonReq}\nDRY_RUN_RESPONSE:\n{jsonRes}");

        Assert.True(result.DryRun);
        Assert.True(result.IsDryRun);
        Assert.Equal(3, result.PlannedCount);
        Assert.Equal(0, result.CreatedCount);
        Assert.Equal(0, result.SkippedExisting);
        Assert.Equal(1, result.SkippedNoDefaultSemester);
        Assert.True(result.TermIsActive);
        Assert.Equal(2, result.PerYear[1]); // 2 subjects in year 1
        Assert.Equal(1, result.PerYear[3]); // 1 subject in year 3
        Assert.Equal(3, result.SampleClassNames.Count);
        Assert.Equal(0, await _db.Classes.CountAsync());
    }

    [Fact]
    public async Task RealRun_CreatesExpectedClasses()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, Sections = 1 };

        var result = await _svc.OpenTermAsync(req, dryRun: false, _callerUserId);

        var jsonReq = System.Text.Json.JsonSerializer.Serialize(req, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
        var jsonRes = System.Text.Json.JsonSerializer.Serialize(result, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
        _output.WriteLine($"REAL_REQUEST:\n{jsonReq}\nREAL_RESPONSE:\n{jsonRes}");

        Assert.False(result.DryRun);
        Assert.False(result.IsDryRun);
        Assert.Equal(3, result.PlannedCount);
        Assert.Equal(3, result.CreatedCount);
        Assert.Equal(0, result.SkippedExisting);
        Assert.Equal(1, result.SkippedNoDefaultSemester);
        Assert.True(result.TermIsActive);
        Assert.Equal(2, result.PerYear[1]);
        Assert.Equal(1, result.PerYear[3]);
        Assert.Equal(3, result.SampleClassNames.Count);
        Assert.Equal(3, await _db.Classes.CountAsync());
    }

    [Fact]
    public async Task SecondRun_CreatesZeroClasses_Idempotent()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, Sections = 1 };

        await _svc.OpenTermAsync(req, dryRun: false, _callerUserId);
        var secondResult = await _svc.OpenTermAsync(req, dryRun: false, _callerUserId);

        Assert.Equal(0, secondResult.CreatedCount);
        Assert.Equal(3, secondResult.SkippedExisting);
        Assert.Equal(0, secondResult.PlannedCount);
        Assert.Equal(3, await _db.Classes.CountAsync()); // still 3, not 6
    }

    [Fact]
    public async Task Sections2_CreatesBothLetters()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, Sections = 2 };

        var result = await _svc.OpenTermAsync(req, dryRun: false, _callerUserId);

        // 3 subjects * 2 sections = 6
        Assert.Equal(6, result.CreatedCount);

        var names = await _db.Classes.Select(c => c.ClassName).OrderBy(n => n).ToListAsync();
        // Check that A and B are both present using ClassNameHelper
        Assert.Contains(ClassNameHelper.Format("BSIT", 1, "A"), names);
        Assert.Contains(ClassNameHelper.Format("BSIT", 1, "B"), names);
    }

    [Fact]
    public async Task YearLevelFilter_OnlyCreatesForRequestedYear()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, YearLevel = 1, Sections = 1 };

        var result = await _svc.OpenTermAsync(req, dryRun: false, _callerUserId);

        // Only Year-1 Sem-1 subjects (2), skipping Year-3
        Assert.Equal(2, result.Created);

        var names = await _db.Classes.Select(c => c.ClassName).ToListAsync();
        Assert.All(names, n => Assert.StartsWith("BSIT 1", n));
    }

    [Fact]
    public async Task SummerTerm_MatchesSummerSubjectsOnly()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termSummer, Sections = 1 };

        var result = await _svc.OpenTermAsync(req, dryRun: false, _callerUserId);

        // Only the summer OJT subject
        Assert.Equal(1, result.Created);
        var cls = await _db.Classes.FirstAsync();
        Assert.Contains("BSIT 4", cls.ClassName);
    }

    [Fact]
    public async Task SubjectsWithNoDefaultSemester_AreSkippedAndCounted()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, YearLevel = 1, Sections = 1 };

        var result = await _svc.OpenTermAsync(req, dryRun: false, _callerUserId);

        // IT 103 (PE 1) has DefaultSemester == 0, must be skipped
        Assert.Equal(1, result.SkippedNoDefaultSemester);
    }

    [Fact]
    public async Task Sections0_ThrowsArgumentOutOfRange()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, Sections = 0 };

        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(
            () => _svc.OpenTermAsync(req, dryRun: false, _callerUserId));
    }

    [Fact]
    public async Task Sections7_ThrowsArgumentOutOfRange()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, Sections = 7 };

        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(
            () => _svc.OpenTermAsync(req, dryRun: false, _callerUserId));
    }

    [Fact]
    public async Task Over500Classes_ThrowsInvalidOperation()
    {
        // Seed enough subjects to exceed 500
        for (int i = 0; i < 100; i++)
        {
            _db.Subjects.Add(new Subject
            {
                SubjectID = Guid.NewGuid(),
                SubjectCode = $"IT X{i:D3}",
                SubjectTitle = $"Subject {i}",
                ProgramID = _programId,
                YearLevel = 1,
                DefaultSemester = 1,
                LecUnits = 3, LabUnits = 0, LecHours = 3, LabHours = 0
            });
        }
        await _db.SaveChangesAsync();

        // sections=6 × 102 subjects = 612 > 500
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, Sections = 6 };

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => _svc.OpenTermAsync(req, dryRun: false, _callerUserId));

        // Nothing committed
        Assert.Equal(0, await _db.Classes.CountAsync());
    }

    [Fact]
    public async Task UnknownProgram_ThrowsKeyNotFound()
    {
        var req = new OpenTermRequestDto { ProgramId = 9999, TermId = _termId1st, Sections = 1 };

        await Assert.ThrowsAsync<KeyNotFoundException>(
            () => _svc.OpenTermAsync(req, dryRun: false, _callerUserId));
    }

    [Fact]
    public async Task UnknownTerm_ThrowsKeyNotFound()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = Guid.NewGuid(), Sections = 1 };

        await Assert.ThrowsAsync<KeyNotFoundException>(
            () => _svc.OpenTermAsync(req, dryRun: false, _callerUserId));
    }

    [Fact]
    public async Task SampleClassNames_ContainsUpTo50Names()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, Sections = 1 };

        var result = await _svc.OpenTermAsync(req, dryRun: true, _callerUserId);

        Assert.True(result.SampleClassNames.Count <= 50);
        Assert.All(result.SampleClassNames, n => Assert.StartsWith("BSIT ", n));
    }

    [Fact]
    public async Task TermIsActive_ReflectedInResult()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, Sections = 1 };
        var result = await _svc.OpenTermAsync(req, dryRun: true, _callerUserId);
        Assert.True(result.TermIsActive); // _termId1st has IsActive=true

        var req2 = new OpenTermRequestDto { ProgramId = _programId, TermId = _termSummer, Sections = 1 };
        var result2 = await _svc.OpenTermAsync(req2, dryRun: true, _callerUserId);
        Assert.False(result2.TermIsActive); // _termSummer has IsActive=false
    }

    [Fact]
    public async Task PerYear_BreakdownIsCorrect()
    {
        var req = new OpenTermRequestDto { ProgramId = _programId, TermId = _termId1st, Sections = 1 };
        var result = await _svc.OpenTermAsync(req, dryRun: true, _callerUserId);

        Assert.True(result.PerYear.ContainsKey(1));
        Assert.True(result.PerYear.ContainsKey(3));
        Assert.Equal(2, result.PerYear[1]); // 2 Sem-1 subjects in Yr1
        Assert.Equal(1, result.PerYear[3]); // 1 Sem-1 subject in Yr3
        // Program has 1 no-semester subject (IT 103)
        Assert.Equal(1, result.SkippedNoDefaultSemester);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller-level role tests (mock service)
// ─────────────────────────────────────────────────────────────────────────────

public class OpenTermControllerRoleTests
{
    private readonly Mock<IClassService> _classSvcMock = new();
    private readonly Mock<IClassScheduleService> _scheduleSvcMock = new();
    private readonly Mock<IProgramScopingService> _scopingSvcMock = new();
    private readonly Mock<IClassRepository> _classRepoMock = new();
    private readonly Mock<ISubjectRepository> _subjectRepoMock = new();
    private readonly Mock<IUserDetailsRepository> _userDetailsRepoMock = new();
    private readonly ClassesController _controller;

    private static readonly Guid ProgramId = Guid.NewGuid();
    private static readonly Guid TermId = Guid.NewGuid();

    public OpenTermControllerRoleTests()
    {
        _controller = new ClassesController(
            _classSvcMock.Object,
            _scheduleSvcMock.Object,
            _scopingSvcMock.Object,
            _classRepoMock.Object,
            _subjectRepoMock.Object,
            _userDetailsRepoMock.Object);

        // Default: service returns a stub result
        _classSvcMock.Setup(s => s.OpenTermAsync(It.IsAny<OpenTermRequestDto>(), It.IsAny<bool>(), It.IsAny<Guid>()))
            .ReturnsAsync(new OpenTermResultDto { WouldCreate = 2, IsDryRun = true });
    }

    private void SetContext(int role, Guid userId)
    {
        var ctx = new DefaultHttpContext();
        ctx.Items["role"] = role;
        ctx.Items["user_id"] = userId;
        _controller.ControllerContext = new ControllerContext { HttpContext = ctx };
    }

    private OpenTermRequestDto MakeDto(int programId = 1) => new OpenTermRequestDto
    {
        ProgramId = programId,
        TermId = TermId,
        Sections = 1
    };

    // Allowed roles ---------------------------------------------------------

    [Fact]
    public async Task Admin_CanOpenTerm()
    {
        SetContext(RoleUtils.Admin, Guid.NewGuid());
        var result = await _controller.OpenTerm(dryRun: true, MakeDto());
        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task Registrar_CanOpenTerm()
    {
        SetContext(RoleUtils.Registrar, Guid.NewGuid());
        var result = await _controller.OpenTerm(dryRun: true, MakeDto());
        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task ProgramHead_OwnProgram_Returns200()
    {
        var userId = Guid.NewGuid();
        SetContext(RoleUtils.ProgramHead, userId);

        // Scoping passes silently
        _scopingSvcMock.Setup(s => s.EnsureProgramHeadAccessAsync(userId, 1, It.IsAny<string>()))
            .Returns(Task.CompletedTask);

        var result = await _controller.OpenTerm(dryRun: true, MakeDto(programId: 1));
        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task ProgramHead_OtherProgram_Returns403()
    {
        var userId = Guid.NewGuid();
        SetContext(RoleUtils.ProgramHead, userId);

        _scopingSvcMock.Setup(s => s.EnsureProgramHeadAccessAsync(userId, 2, It.IsAny<string>()))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied. This program belongs to a different program."));

        var result = await _controller.OpenTerm(dryRun: true, MakeDto(programId: 2));
        var objResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(403, objResult.StatusCode);
    }

    [Fact]
    public async Task ProgramHead_NoProgram_Returns403()
    {
        var userId = Guid.NewGuid();
        SetContext(RoleUtils.ProgramHead, userId);

        _scopingSvcMock.Setup(s => s.EnsureProgramHeadAccessAsync(userId, It.IsAny<int>(), It.IsAny<string>()))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied. Your account is not assigned to an academic program."));

        var result = await _controller.OpenTerm(dryRun: true, MakeDto());
        var objResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(403, objResult.StatusCode);
    }

    // Forbidden roles -------------------------------------------------------

    [Theory]
    [InlineData(RoleUtils.Teacher)]
    [InlineData(RoleUtils.Student)]
    [InlineData(RoleUtils.CollegeHead)]
    public async Task ForbiddenRoles_Return403(int role)
    {
        SetContext(role, Guid.NewGuid());
        var result = await _controller.OpenTerm(dryRun: true, MakeDto());
        var objResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(403, objResult.StatusCode);
    }

    // Validation errors from service ----------------------------------------

    [Fact]
    public async Task ServiceThrows_ArgumentOutOfRange_Returns400()
    {
        SetContext(RoleUtils.Admin, Guid.NewGuid());
        _classSvcMock.Setup(s => s.OpenTermAsync(It.IsAny<OpenTermRequestDto>(), It.IsAny<bool>(), It.IsAny<Guid>()))
            .ThrowsAsync(new ArgumentOutOfRangeException("Sections", "Sections must be between 1 and 6."));

        var result = await _controller.OpenTerm(dryRun: false, MakeDto());
        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task ServiceThrows_InvalidOperation_Returns400()
    {
        SetContext(RoleUtils.Admin, Guid.NewGuid());
        _classSvcMock.Setup(s => s.OpenTermAsync(It.IsAny<OpenTermRequestDto>(), It.IsAny<bool>(), It.IsAny<Guid>()))
            .ThrowsAsync(new InvalidOperationException("Exceeds 500 class limit."));

        var result = await _controller.OpenTerm(dryRun: false, MakeDto());
        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task ServiceThrows_KeyNotFound_Returns404()
    {
        SetContext(RoleUtils.Admin, Guid.NewGuid());
        _classSvcMock.Setup(s => s.OpenTermAsync(It.IsAny<OpenTermRequestDto>(), It.IsAny<bool>(), It.IsAny<Guid>()))
            .ThrowsAsync(new KeyNotFoundException("Term not found."));

        var result = await _controller.OpenTerm(dryRun: false, MakeDto());
        Assert.IsType<NotFoundObjectResult>(result);
    }
}
