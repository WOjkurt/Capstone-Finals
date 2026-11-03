using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

// The system suggests the next year level (75% of the year's units passed); the Registrar decides.
public class YearLevelSuggestionTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly StudyLoadService _service;
    private readonly StudyLoadsController _controller;
    private readonly Guid _studentId = Guid.NewGuid();
    private readonly Guid _termId = Guid.NewGuid();
    private readonly Dictionary<string, Subject> _subjects = new();

    public YearLevelSuggestionTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _service = new StudyLoadService(_context, new StudyLoadRepository(_context),
            new Mock<IGradeClearanceService>().Object, NullLogger<StudyLoadService>.Instance);
        _controller = new StudyLoadsController(_service, new ClassRepository(_context),
            new UserDetailsRepository(_context), new Mock<IProgramScopingService>().Object);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _termId, SchoolYear = "2025-2026", Semester = 1 });
        _context.Users.Add(new User { UserID = _studentId, FirebaseUID = "fb-s", Email = "s@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _studentId, Firstname = "Ana", Lastname = "Cruz", ProgramID = 1, YearLevel = 1 });

        // Year 1: four 3-unit subjects (12 units), two of them minor. Year 2 and Year 4 exist so Year 4 is the final year.
        AddSubject("IT 101", 1);
        AddSubject("IT 102", 1);
        AddSubject("GEC 101", 1, isMinor: true);
        AddSubject("THEO 101", 1, isMinor: true);
        AddSubject("IT 201", 2);
        AddSubject("IT 401", 4);
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void AddSubject(string code, int year, bool isMinor = false)
    {
        var s = new Subject
        {
            SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code, LecUnits = 2, LabUnits = 1,
            ProgramID = 1, YearLevel = year, DefaultSemester = 1, IsMinor = isMinor
        };
        _subjects[code] = s;
        _context.Subjects.Add(s);
    }

    // remarks: 1 Passed, 2 Failed, null = no final grade yet.
    private async Task Took(string code, int? remarks, int status = StudyLoadStatus.Enrolled)
    {
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = _subjects[code].SubjectID, TermID = _termId, ClassName = "BSIT 1A", CreatedAt = DateTime.UtcNow };
        var load = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = _studentId, ClassID = cls.ClassID, LoadStatus = status, CreatedAt = DateTime.UtcNow };
        _context.Classes.Add(cls);
        _context.StudyLoads.Add(load);
        if (remarks.HasValue)
        {
            _context.Grades.Add(new Grade { GradeID = Guid.NewGuid(), StudyLoadID = load.StudyLoadID, FinalGrade = remarks == 1 ? 2.0m : 5.0m, Remarks = remarks });
        }
        await _context.SaveChangesAsync();
    }

    private async Task SetYearLevel(int year)
    {
        var ud = await _context.UserDetails.FirstAsync(u => u.UserID == _studentId);
        ud.YearLevel = year;
        await _context.SaveChangesAsync();
    }

    [Fact]
    public async Task PassedAllUnits_SuggestsNextYear()
    {
        foreach (var code in new[] { "IT 101", "IT 102", "GEC 101", "THEO 101" }) await Took(code, 1);

        var r = await _service.GetYearLevelSuggestionAsync(_studentId);

        Assert.Equal(1, r.CurrentYearLevel);
        Assert.Equal(2, r.SuggestedYearLevel);
        Assert.Equal(12m, r.PassedUnits);
        Assert.Equal(12m, r.TotalUnits);
        Assert.Equal(4, r.PassedSubjects);
    }

    [Fact]
    public async Task ExactlySeventyFivePercent_SuggestsNextYear()
    {
        await Took("IT 101", 1);
        await Took("IT 102", 1);
        await Took("GEC 101", 1);
        await Took("THEO 101", 2);

        var r = await _service.GetYearLevelSuggestionAsync(_studentId);

        Assert.Equal(2, r.SuggestedYearLevel);
        Assert.Equal(new[] { "THEO 101" }, r.FailedSubjectCodes);
        Assert.Contains("Passed 9 of 12 units (75%)", r.Reason);
    }

    [Fact]
    public async Task BelowSeventyFivePercent_StaysInSameYear()
    {
        await Took("IT 101", 1);
        await Took("IT 102", 1);
        await Took("GEC 101", 2);

        var r = await _service.GetYearLevelSuggestionAsync(_studentId);

        Assert.Equal(1, r.SuggestedYearLevel);
        Assert.Equal(new[] { "GEC 101" }, r.FailedSubjectCodes);
        Assert.Equal(new[] { "THEO 101" }, r.NotTakenSubjectCodes);
        Assert.Contains("(50%)", r.Reason);
    }

    [Fact]
    public async Task FailedThenPassedOnRetake_CountsAsPassed()
    {
        await Took("IT 101", 2);
        await Took("IT 101", 1);
        await Took("IT 102", 1);
        await Took("GEC 101", 1);

        var r = await _service.GetYearLevelSuggestionAsync(_studentId);

        Assert.Equal(2, r.SuggestedYearLevel);
        Assert.Empty(r.FailedSubjectCodes);
    }

    [Fact]
    public async Task PendingAndDroppedLoads_DoNotCountAsPassed_AndUngradedIsReported()
    {
        await Took("IT 101", 1);
        await Took("IT 102", null);
        await Took("GEC 101", 1, StudyLoadStatus.Pending);
        await Took("THEO 101", 1, StudyLoadStatus.Dropped);

        var r = await _service.GetYearLevelSuggestionAsync(_studentId);

        Assert.Equal(1, r.SuggestedYearLevel);
        Assert.Equal(3m, r.PassedUnits);
        Assert.Equal(1, r.UngradedSubjects);
        Assert.Contains("1 subject(s) still have no final grade", r.Reason);
    }

    [Fact]
    public async Task FinalYear_NeverSuggestsHigher()
    {
        await SetYearLevel(4);
        await Took("IT 401", 1);

        var r = await _service.GetYearLevelSuggestionAsync(_studentId);

        Assert.True(r.IsFinalYear);
        Assert.Equal(4, r.SuggestedYearLevel);
        Assert.Contains("final year", r.Reason);
    }

    [Fact]
    public async Task OnlyCurrentYearSubjectsCount()
    {
        await SetYearLevel(2);
        await Took("IT 201", 1);

        var r = await _service.GetYearLevelSuggestionAsync(_studentId);

        Assert.Equal(1, r.TotalSubjects);
        Assert.Equal(3, r.SuggestedYearLevel);
    }

    [Fact]
    public async Task NoYearLevel_ReturnsBadRequest()
    {
        var ud = await _context.UserDetails.FirstAsync(u => u.UserID == _studentId);
        ud.YearLevel = null;
        await _context.SaveChangesAsync();

        var result = await _controller.GetYearLevelSuggestion(_studentId);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task UnknownStudent_ReturnsNotFound()
    {
        Assert.IsType<NotFoundObjectResult>(await _controller.GetYearLevelSuggestion(Guid.NewGuid()));
    }

    [Fact]
    public async Task Endpoint_ReturnsSuggestion()
    {
        var result = await _controller.GetYearLevelSuggestion(_studentId);

        var ok = Assert.IsType<OkObjectResult>(result);
        Assert.IsType<YearLevelSuggestionDto>(ok.Value);
    }

    [Fact]
    public void Endpoint_IsRegistrarOrAdminOnly()
    {
        var method = typeof(StudyLoadsController).GetMethod(nameof(StudyLoadsController.GetYearLevelSuggestion))!;
        Assert.NotNull(method.GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), false).SingleOrDefault());
    }

    // ── Major-units condition ───────────────────────────────────────

    // A year that is mostly minor units: 4 minors (12 units) and 1 major (3 units).
    private async Task UseMostlyMinorYear()
    {
        await SetYearLevel(2);
        AddSubject("GEC 201", 2, isMinor: true);
        AddSubject("GEC 202", 2, isMinor: true);
        AddSubject("THEO 201", 2, isMinor: true);
        await _context.SaveChangesAsync();
    }

    [Fact]
    public async Task PassedOnlyMinors_AboveSeventyFivePercent_StillStays()
    {
        await UseMostlyMinorYear();
        // Year 2 now: IT 201 (major) + GEC 201, GEC 202, THEO 201 (minor) = 12 units; pass the 9 minor units.
        foreach (var code in new[] { "GEC 201", "GEC 202", "THEO 201" }) await Took(code, 1);
        await Took("IT 201", 2);

        var r = await _service.GetYearLevelSuggestionAsync(_studentId);

        Assert.Equal(2, r.SuggestedYearLevel);
        Assert.Equal(9m, r.PassedUnits);
        Assert.Equal(0m, r.PassedMajorUnits);
        Assert.Equal(3m, r.TotalMajorUnits);
        Assert.Contains("but only 0 of 3 major units (0%)", r.Reason);
    }

    [Fact]
    public async Task PassedEnoughMajorsAndUnits_MovesUp()
    {
        await UseMostlyMinorYear();
        foreach (var code in new[] { "IT 201", "GEC 201", "GEC 202" }) await Took(code, 1);

        var r = await _service.GetYearLevelSuggestionAsync(_studentId);

        Assert.Equal(3, r.SuggestedYearLevel);
        Assert.Equal(3m, r.PassedMajorUnits);
    }

    [Fact]
    public async Task YearWithNoMajors_UsesOnlyTheUnitsCondition()
    {
        await SetYearLevel(2);
        var it201 = await _context.Subjects.FirstAsync(s => s.SubjectCode == "IT 201");
        it201.IsMinor = true;
        await _context.SaveChangesAsync();
        await Took("IT 201", 1);

        var r = await _service.GetYearLevelSuggestionAsync(_studentId);

        Assert.Equal(0m, r.TotalMajorUnits);
        Assert.Equal(3, r.SuggestedYearLevel);
    }
}
