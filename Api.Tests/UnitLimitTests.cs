using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

// CHED-style unit limits shown as a warning in the study load builder.
public class UnitLimitTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly StudyLoadService _service;
    private readonly Guid _studentId = Guid.NewGuid();
    private readonly Guid _sem1 = Guid.NewGuid();
    private readonly Guid _summer = Guid.NewGuid();

    public UnitLimitTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _service = new StudyLoadService(_context, new StudyLoadRepository(_context),
            new Mock<IGradeClearanceService>().Object, NullLogger<StudyLoadService>.Instance);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.AcademicTerms.AddRange(
            new AcademicTerm { TermID = _sem1, SchoolYear = "2026-2027", Semester = 1 },
            new AcademicTerm { TermID = _summer, SchoolYear = "2026-2027", Semester = 3 });
        _context.Users.Add(new User { UserID = _studentId, FirebaseUID = "fb", Email = "s@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _studentId, Firstname = "Ana", Lastname = "Cruz", ProgramID = 1, YearLevel = 1 });

        // Year 1 Sem 1: 3 + 3 + 2 = 8 units (lec + lab). Year 4 exists so Year 4 is the final year.
        AddSubject("IT 101", 1, 1, 2, 1);
        AddSubject("IT 102", 1, 1, 3, 0);
        AddSubject("PE 101", 1, 1, 2, 0);
        AddSubject("IT 103", 1, 2, 3, 0);
        AddSubject("IT 401", 4, 1, 3, 0);
        AddSubject("IT 402", 4, 1, 3, 0);
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private readonly Dictionary<string, Subject> _subjects = new();

    private void AddSubject(string code, int year, int sem, decimal lec, decimal lab)
    {
        var s = new Subject
        {
            SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code, LecUnits = lec, LabUnits = lab,
            ProgramID = 1, YearLevel = year, DefaultSemester = sem
        };
        _subjects[code] = s;
        _context.Subjects.Add(s);
    }

    private async Task Load(string code, Guid termId, int status)
    {
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = _subjects[code].SubjectID, TermID = termId, ClassName = "BSIT 1A", CreatedAt = DateTime.UtcNow };
        _context.Classes.Add(cls);
        _context.StudyLoads.Add(new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = _studentId, ClassID = cls.ClassID, LoadStatus = status, CreatedAt = DateTime.UtcNow });
        await _context.SaveChangesAsync();
    }

    private async Task SetYearLevel(int year)
    {
        var ud = await _context.UserDetails.FirstAsync(u => u.UserID == _studentId);
        ud.YearLevel = year;
        await _context.SaveChangesAsync();
    }

    [Fact]
    public async Task RegularSemester_LimitIsTheCurriculumLoad()
    {
        var r = await _service.GetUnitLimitAsync(_studentId, _sem1);

        Assert.Equal(8m, r.CurriculumUnits);
        Assert.Equal(8m, r.MaxUnits);
        Assert.False(r.IsGraduating);
        Assert.Contains("Overload is allowed only for graduating students", r.Rule);
    }

    [Fact]
    public async Task GraduatingStudent_GetsSixUnitOverload()
    {
        await SetYearLevel(4);

        var r = await _service.GetUnitLimitAsync(_studentId, _sem1);

        Assert.True(r.IsGraduating);
        Assert.Equal(12m, r.MaxUnits); // 6 curriculum + 6 overload
    }

    [Fact]
    public async Task NoCurriculumForTheTerm_FallsBackTo21()
    {
        await SetYearLevel(2);

        var r = await _service.GetUnitLimitAsync(_studentId, _sem1);

        Assert.Equal(0m, r.CurriculumUnits);
        Assert.Equal(21m, r.MaxUnits);
    }

    [Fact]
    public async Task SummerLimits_CanBeChangedByTheRegistrar()
    {
        var settings = new SchoolSettingsService(_context);
        Assert.Equal((9m, 12m, (DateTime?)null), ((await settings.GetUnitLimitsAsync()).SummerMaxUnits, (await settings.GetUnitLimitsAsync()).GraduatingSummerMaxUnits, (await settings.GetUnitLimitsAsync()).UpdatedAt));

        await settings.SaveUnitLimitsAsync(new Api.DTOs.Setup.SaveUnitLimitSettingsDto { SummerMaxUnits = 6, GraduatingSummerMaxUnits = 10.5m }, _studentId);

        var r = await _service.GetUnitLimitAsync(_studentId, _summer);
        Assert.Equal((6m, "Summer limit: 6 units."), (r.MaxUnits, r.Rule));
        var saved = await settings.GetUnitLimitsAsync();
        Assert.Equal((6m, 10.5m), (saved.SummerMaxUnits, saved.GraduatingSummerMaxUnits));
        Assert.NotNull(saved.UpdatedAt);

        await settings.SaveUnitLimitsAsync(new Api.DTOs.Setup.SaveUnitLimitSettingsDto { SummerMaxUnits = 7, GraduatingSummerMaxUnits = 10 }, _studentId);
        Assert.Equal(1, await _context.SchoolSettings.CountAsync());   // always one row

        foreach (var (summer, graduating) in new[] { (0m, 12m), (9m, 31m), (12m, 9m) })
        {
            await Assert.ThrowsAsync<InvalidOperationException>(() => settings.SaveUnitLimitsAsync(new Api.DTOs.Setup.SaveUnitLimitSettingsDto { SummerMaxUnits = summer, GraduatingSummerMaxUnits = graduating }, _studentId));
        }
    }

    [Fact]
    public async Task Summer_IsNineUnits_OrTwelveWhenGraduating()
    {
        Assert.Equal(9m, (await _service.GetUnitLimitAsync(_studentId, _summer)).MaxUnits);

        await SetYearLevel(4);
        var r = await _service.GetUnitLimitAsync(_studentId, _summer);
        Assert.True(r.IsSummer);
        Assert.Equal(12m, r.MaxUnits);
    }

    [Fact]
    public async Task CurrentUnits_CountEnrolledAndPendingOnly_InThatTerm()
    {
        await Load("IT 101", _sem1, StudyLoadStatus.Enrolled);  // 3
        await Load("IT 102", _sem1, StudyLoadStatus.Pending);   // 3
        await Load("PE 101", _sem1, StudyLoadStatus.Dropped);   // not counted
        await Load("IT 103", _summer, StudyLoadStatus.Enrolled); // other term

        var r = await _service.GetUnitLimitAsync(_studentId, _sem1);

        Assert.Equal(6m, r.CurrentUnits);
    }

    [Fact]
    public async Task UnknownStudentOrTerm_Throws()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.GetUnitLimitAsync(Guid.NewGuid(), _sem1));
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.GetUnitLimitAsync(_studentId, Guid.NewGuid()));
    }

    // ── Overload approval on save ───────────────────────────────────

    private readonly Guid _collegeHeadId = Guid.NewGuid();

    private async Task<List<Guid>> OpenClasses(params string[] codes)
    {
        if (!await _context.Users.AnyAsync(u => u.UserID == _collegeHeadId))
        {
            _context.Users.Add(new User { UserID = _collegeHeadId, FirebaseUID = "fb-ch", Email = "ch@dbtc-cebu.edu.ph", Role = RoleUtils.CollegeHead, IsActive = true });
            _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _collegeHeadId, Firstname = "Carla", Lastname = "Head" });
        }
        var ids = new List<Guid>();
        foreach (var code in codes)
        {
            var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = _subjects[code].SubjectID, TermID = _sem1, ClassName = "BSIT 1A", CreatedAt = DateTime.UtcNow };
            _context.Classes.Add(cls);
            ids.Add(cls.ClassID);
        }
        await _context.SaveChangesAsync();
        return ids;
    }

    private Task<List<EnrollBatchResponseDto>> Save(List<Guid> classIds, string? reason) =>
        _service.EnrollBatchAsync(new EnrollBatchRequestDto
        {
            UserId = _studentId, TermId = _sem1, ClassIds = classIds, AsPending = true, OverloadReason = reason
        }, _collegeHeadId, RoleUtils.CollegeHead);

    [Fact]
    public async Task Save_WithinLimit_NeedsNoReason_AndRecordsNothing()
    {
        var result = await Save(await OpenClasses("IT 101", "IT 102", "PE 101"), null); // 8 of 8

        Assert.All(result, r => Assert.True(r.Enrolled));
        Assert.Empty(await _context.OverloadApprovals.ToListAsync());
    }

    [Fact]
    public async Task Save_OverLimit_WithoutReason_IsRefused_AndNothingIsSaved()
    {
        var classes = await OpenClasses("IT 101", "IT 102", "PE 101", "IT 103"); // 11 of 8

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => Save(classes, "  "));

        Assert.Contains("11 units, over the limit of 8", ex.Message);
        Assert.Empty(await _context.StudyLoads.ToListAsync());
    }

    [Fact]
    public async Task Save_OverLimit_WithReason_SavesAndRecordsTheApproval()
    {
        var classes = await OpenClasses("IT 101", "IT 102", "PE 101", "IT 103");

        var result = await Save(classes, " Irregular student catching up ");

        Assert.All(result, r => Assert.NotNull(r.StudyLoadId));
        var approval = await _context.OverloadApprovals.SingleAsync();
        Assert.Equal(11m, approval.Units);
        Assert.Equal(8m, approval.MaxUnits);
        Assert.Equal("Irregular student catching up", approval.Reason);
        Assert.Equal(_collegeHeadId, approval.ApprovedByUserID);

        var limit = await _service.GetUnitLimitAsync(_studentId, _sem1);
        Assert.True(limit.IsOverloaded);
        Assert.Equal("Carla Head", limit.OverloadApprovedBy);
        Assert.Equal("Irregular student catching up", limit.OverloadReason);
    }

    [Fact]
    public async Task SecondOverloadSave_ReplacesTheApproval()
    {
        var first = await OpenClasses("IT 101", "IT 102", "PE 101", "IT 103");
        await Save(first, "first reason");
        var second = await OpenClasses("IT 401");

        await Save(second, "second reason");

        var approval = await _context.OverloadApprovals.SingleAsync();
        Assert.Equal("second reason", approval.Reason);
        Assert.Equal(14m, approval.Units);
    }

    [Fact]
    public async Task PendingSummary_ShowsOverloadAndApprover()
    {
        _context.AcademicTerms.First(t => t.TermID == _sem1).IsActive = true;
        await _context.SaveChangesAsync();
        await Save(await OpenClasses("IT 101", "IT 102", "PE 101", "IT 103"), "catching up");

        var row = Assert.Single(await _service.GetPendingSummaryAsync(_sem1));

        Assert.True(row.IsOverloaded);
        Assert.Equal(11m, row.TermUnits);
        Assert.Equal(8m, row.MaxUnits);
        Assert.Equal("Carla Head", row.OverloadApprovedBy);
        Assert.Equal("catching up", row.OverloadReason);
    }
}
