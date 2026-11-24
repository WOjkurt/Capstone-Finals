using Api.Auth;
using Api.Controllers;
using Api.Domain.Audit;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.Grading;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The Registrar changing a grade that is already recorded — what replaces the correction
/// request now that almost no class has a teacher to raise one.
///
/// The checks matter more than the write. A grade is the record a transcript is built from, so
/// what must not be possible is quietly moving an old one, moving one off the scale, or moving
/// one without saying why.
/// </summary>
public class GradeModificationTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly GradeService _service;
    private readonly Guid _registrar = Guid.NewGuid();
    private readonly Guid _student = Guid.NewGuid();
    private readonly Guid _teacher = Guid.NewGuid();

    private readonly AcademicTerm _active = new()
    { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 2, IsActive = true };
    private readonly AcademicTerm _lastYear = new()
    { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };

    private Guid _gradeNow, _gradeThen;

    public GradeModificationTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase("GradeMod_" + Guid.NewGuid()).Options;
        _context = new TestAppDbContext(options);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.AcademicTerms.AddRange(_active, _lastYear);
        _context.Users.AddRange(
            new User { UserID = _registrar, FirebaseUID = "fb-r", Email = "r@dbtc-cebu.edu.ph", Role = RoleUtils.Registrar, IsActive = true },
            new User { UserID = _teacher, FirebaseUID = "fb-t", Email = "t@dbtc-cebu.edu.ph", Role = RoleUtils.Teacher, IsActive = true },
            new User { UserID = _student, FirebaseUID = "fb-s", Email = "s@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails
        { UserDetailID = Guid.NewGuid(), UserID = _student, Firstname = "Ana", Lastname = "Cruz", ProgramID = 1 });

        _gradeNow = Seed(_active, "IT 101", midterm: 2.0m, final: 2.5m);
        _gradeThen = Seed(_lastYear, "IT 100", midterm: 1.75m, final: 1.5m);
        _context.SaveChanges();

        var clearance = new Mock<IGradeClearanceService>();
        clearance.Setup(c => c.IsClearedAsync(It.IsAny<Guid>(), It.IsAny<Guid>())).ReturnsAsync(true);
        _service = new GradeService(_context, new GradeRepository(_context), clearance.Object,
            new Mock<IProgramScopingService>().Object);
    }

    private Guid Seed(AcademicTerm term, string code, decimal midterm, decimal final)
    {
        var subject = new Subject
        { SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code, LecUnits = 3, ProgramID = 1, YearLevel = 1, DefaultSemester = 1 };
        var cls = new Class
        { ClassID = Guid.NewGuid(), SubjectID = subject.SubjectID, TermID = term.TermID, ClassName = code + " A", UserID = _teacher, CreatedAt = DateTime.UtcNow };
        var load = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = _student, ClassID = cls.ClassID, LoadStatus = 2 };
        var grade = new Grade
        {
            GradeID = Guid.NewGuid(),
            StudyLoadID = load.StudyLoadID,
            MidtermGrade = midterm,
            FinalGrade = final,
            Remarks = final > 3.0m ? 2 : 1,
            SubmittedByUserID = _teacher,
            DateSubmitted = new DateTime(2026, 10, 1, 0, 0, 0, DateTimeKind.Utc),
        };
        _context.Subjects.Add(subject);
        _context.Classes.Add(cls);
        _context.StudyLoads.Add(load);
        _context.Grades.Add(grade);
        return grade.GradeID;
    }

    public void Dispose() => _context.Dispose();

    private static ModifyGradeDto Change(decimal? midterm = null, decimal? final = null,
        string reason = "Teacher sent the wrong column") =>
        new() { MidtermGrade = midterm, FinalGrade = final, Reason = reason };

    private Task<Grade> Stored(Guid id) => _context.Grades.AsNoTracking().FirstAsync(g => g.GradeID == id);

    // ── Writing the change ───────────────────────────────────────────────────

    [Fact]
    public async Task ChangingTheFinal_WritesIt_AndRedecidesPassedOrFailed()
    {
        await _service.ModifyAsync(_gradeNow, Change(final: 3.5m), _registrar);

        var saved = await Stored(_gradeNow);
        Assert.Equal(3.5m, saved.FinalGrade);
        Assert.Equal(2, saved.Remarks);   // above 3.0 is failed
        Assert.Equal(2.0m, saved.MidtermGrade);  // untouched
    }

    [Fact]
    public async Task ChangingAFailIntoAPass_RedecidesTheOtherWay()
    {
        await _service.ModifyAsync(_gradeNow, Change(final: 5.0m), _registrar);
        Assert.Equal(2, (await Stored(_gradeNow)).Remarks);

        await _service.ModifyAsync(_gradeNow, Change(final: 2.0m), _registrar);
        Assert.Equal(1, (await Stored(_gradeNow)).Remarks);
    }

    [Fact]
    public async Task ChangingOnlyTheMidterm_LeavesTheFinalAndItsRemarksAlone()
    {
        await _service.ModifyAsync(_gradeNow, Change(midterm: 1.25m), _registrar);

        var saved = await Stored(_gradeNow);
        Assert.Equal(1.25m, saved.MidtermGrade);
        Assert.Equal(2.5m, saved.FinalGrade);
        Assert.Equal(1, saved.Remarks);
    }

    [Fact]
    public async Task AChangeRecordsWhoChangedIt_WhenAndWhy()
    {
        await _service.ModifyAsync(_gradeNow, Change(final: 2.0m, reason: "  Encoded from the wrong sheet  "), _registrar);

        var saved = await Stored(_gradeNow);
        Assert.NotNull(saved.ModifiedAt);
        Assert.Equal(_registrar, saved.ModifiedByUserID);
        Assert.Equal("Encoded from the wrong sheet", saved.ModificationReason);
    }

    [Fact]
    public async Task AChangeLeavesDateSubmittedWhereItWas()
    {
        var before = (await Stored(_gradeNow)).DateSubmitted;

        await _service.ModifyAsync(_gradeNow, Change(final: 2.0m), _registrar);

        // Moving it would erase the fact that the grade was changed at all.
        Assert.Equal(before, (await Stored(_gradeNow)).DateSubmitted);
    }

    [Fact]
    public async Task TheStudentCanSeeThatItWasChanged()
    {
        var (dto, _, _) = await _service.ModifyAsync(_gradeNow, Change(final: 2.0m), _registrar);

        Assert.NotNull(dto.ModifiedAt);
    }

    [Fact]
    public async Task AGradeNobodyHasTouched_DoesNotLookChanged()
    {
        var untouched = await _service.GetByStudyLoadIdAsync(
            (await Stored(_gradeNow)).StudyLoadID, _registrar, RoleUtils.Registrar);

        Assert.Null(untouched!.ModifiedAt);
    }

    [Fact]
    public async Task TheCallerIsToldWhatItUsedToBe()
    {
        var (_, wasMidterm, wasFinal) = await _service.ModifyAsync(_gradeNow, Change(final: 1.0m), _registrar);

        Assert.Equal(2.0m, wasMidterm);
        Assert.Equal(2.5m, wasFinal);
    }

    // ── What must not be possible ───────────────────────────────────────────

    [Fact]
    public async Task AGradeFromAnEarlierTerm_CannotBeChanged()
    {
        var refused = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.ModifyAsync(_gradeThen, Change(final: 1.0m), _registrar));

        Assert.Contains("currently active", refused.Message);
        Assert.Equal(1.5m, (await Stored(_gradeThen)).FinalGrade);
        Assert.Null((await Stored(_gradeThen)).ModifiedAt);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task AChangeWithoutAReason_IsRefused(string reason)
    {
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.ModifyAsync(_gradeNow, Change(final: 2.0m, reason: reason), _registrar));

        Assert.Null((await Stored(_gradeNow)).ModifiedAt);
    }

    [Theory]
    [InlineData(0.9)]
    [InlineData(5.1)]
    [InlineData(2.33)]
    public async Task AGradeOffTheScale_IsRefused(double offScale)
    {
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.ModifyAsync(_gradeNow, Change(final: (decimal)offScale), _registrar));

        Assert.Equal(2.5m, (await Stored(_gradeNow)).FinalGrade);
    }

    [Fact]
    public async Task AChangeThatNamesNeitherMark_IsRefused()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.ModifyAsync(_gradeNow, Change(), _registrar));
    }

    [Fact]
    public async Task AGradeThatDoesNotExist_IsNotFound()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(
            () => _service.ModifyAsync(Guid.NewGuid(), Change(final: 2.0m), _registrar));
    }

    // ── Through the endpoint, where it is logged ────────────────────────────

    private (GradesController Controller, FakeActivityLog Log) Endpoint()
    {
        var log = new FakeActivityLog();
        var http = new DefaultHttpContext();
        http.Items["user_id"] = _registrar;
        http.Items["role"] = RoleUtils.Registrar;
        http.RequestServices = new SingleService(log.Service);
        return (new GradesController(_service)
        {
            ControllerContext = new ControllerContext { HttpContext = http }
        }, log);
    }

    private sealed class SingleService : IServiceProvider
    {
        private readonly IActivityLogService _log;
        public SingleService(IActivityLogService log) => _log = log;
        public object? GetService(Type serviceType) =>
            serviceType == typeof(IActivityLogService) ? _log : null;
    }

    [Fact]
    public async Task TheLogSaysWhatTheMarkWas_WhatItBecame_AndWhy()
    {
        var (controller, log) = Endpoint();

        var result = await controller.Modify(_gradeNow, Change(final: 1.75m, reason: "Encoding error"));

        Assert.IsType<OkObjectResult>(result);
        var entry = Assert.Single(log.Of(ActivityActions.GradeModified));
        Assert.Equal(_registrar, entry.Actor);
        Assert.Contains("final 2.50 → 1.75", entry.Summary);
        Assert.Contains("Encoding error", entry.Summary);
        Assert.Contains("IT 101", entry.Summary);
        Assert.Equal(_student, entry.StudentId);
    }

    [Fact]
    public async Task ASaveThatChangedNoNumber_IsStillRecorded()
    {
        var (controller, log) = Endpoint();

        // Somebody meant to do something; the reason they typed is worth keeping.
        await controller.Modify(_gradeNow, Change(final: 2.5m, reason: "Checked against the sheet"));

        Assert.Contains("no change", Assert.Single(log.Of(ActivityActions.GradeModified)).Summary);
    }

    [Fact]
    public async Task AnEarlierTermsGradeIsRefusedByTheEndpoint_AndLogsNothing()
    {
        var (controller, log) = Endpoint();

        var result = await controller.Modify(_gradeThen, Change(final: 1.0m));

        Assert.IsType<BadRequestObjectResult>(result);
        Assert.Empty(log.Of(ActivityActions.GradeModified));
    }

    [Fact]
    public async Task AMissingReasonIsRefusedByTheEndpoint()
    {
        var (controller, log) = Endpoint();
        controller.ModelState.AddModelError(nameof(ModifyGradeDto.Reason), "Say why the grade is being changed.");

        var result = await controller.Modify(_gradeNow, Change(final: 2.0m, reason: ""));

        Assert.IsType<BadRequestObjectResult>(result);
        Assert.Empty(log.Of(ActivityActions.GradeModified));
    }

    [Fact]
    public void TheActionIsInTheRegistryTheActivityScreenReadsFrom()
    {
        Assert.Contains(ActivityActions.GradeModified, ActivityActions.All);

        // The retired correction actions stay defined: log rows written under them are still in
        // the table, and would otherwise render as raw codes once the workflow is gone.
        Assert.Contains(ActivityActions.GradeCorrectionApproved, ActivityActions.All);
        Assert.Contains(ActivityActions.GradeCorrectionRejected, ActivityActions.All);
    }
}
