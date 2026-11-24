using Api.Auth;
using Api.Controllers;
using Api.Domain.Audit;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.Setup;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Releasing a term's results, and verifying the sheets that go into them.
///
/// Three separate things decide whether a student sees a mark, and keeping them apart is the
/// point: the term being released is about the whole school being finished, clearance is about
/// that one student, and an Accounting hold is about money. A student told the wrong one walks
/// to the wrong office.
/// </summary>
public class GradeReleaseTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly GradeService _grades;
    private readonly AcademicTermService _terms;
    private readonly ClassService _classes;

    private readonly Guid _registrar = Guid.NewGuid();
    private readonly Guid _programHead = Guid.NewGuid();
    private readonly Guid _otherProgramHead = Guid.NewGuid();
    private readonly Guid _collegeHead = Guid.NewGuid();
    private readonly Guid _teacher = Guid.NewGuid();
    private readonly Guid _student = Guid.NewGuid();

    private readonly Guid _termId = Guid.NewGuid();
    private Guid _classId, _otherProgramClassId, _studyLoadId;

    private readonly Mock<IGradeClearanceService> _clearance = new();

    public GradeReleaseTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase("Release_" + Guid.NewGuid()).Options;
        _context = new TestAppDbContext(options);

        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" },
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSCS", ProgramName = "BS CS" });
        _context.AcademicTerms.Add(new AcademicTerm
        { TermID = _termId, SchoolYear = "2026-2027", Semester = 1, IsActive = true });

        void Staff(Guid id, int role, int? programId)
        {
            _context.Users.Add(new User { UserID = id, FirebaseUID = "fb" + id, Email = id + "@dbtc-cebu.edu.ph", Role = role, IsActive = true });
            _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = id, Firstname = "A", Lastname = "B", ProgramID = programId });
        }
        Staff(_registrar, RoleUtils.Registrar, null);
        Staff(_programHead, RoleUtils.ProgramHead, 1);
        Staff(_otherProgramHead, RoleUtils.ProgramHead, 2);
        Staff(_collegeHead, RoleUtils.CollegeHead, null);
        Staff(_teacher, RoleUtils.Teacher, 1);
        Staff(_student, RoleUtils.Student, 1);

        _classId = Seed(programId: 1, "IT 101", withGrade: true);
        _otherProgramClassId = Seed(programId: 2, "CS 101", withGrade: false);
        _context.SaveChanges();

        _clearance.Setup(c => c.IsClearedAsync(It.IsAny<Guid>(), It.IsAny<Guid>())).ReturnsAsync(true);
        _grades = new GradeService(_context, new GradeRepository(_context), _clearance.Object,
            new Mock<IProgramScopingService>().Object);
        _terms = new AcademicTermService(_context, new AcademicTermRepository(_context));
        var schedules = new Mock<IClassScheduleRepository>();
        schedules.Setup(r => r.GetByClassIdAsync(It.IsAny<Guid>()))
            .ReturnsAsync(new List<Api.Domain.Enrollment.ClassSchedule>());
        _classes = new ClassService(_context, new ClassRepository(_context), schedules.Object);
    }

    private Guid Seed(int programId, string code, bool withGrade)
    {
        var subject = new Subject
        { SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code, LecUnits = 3, ProgramID = programId, YearLevel = 1, DefaultSemester = 1 };
        var cls = new Class
        { ClassID = Guid.NewGuid(), SubjectID = subject.SubjectID, TermID = _termId, ClassName = code + " A", UserID = _teacher, CreatedAt = DateTime.UtcNow };
        _context.Subjects.Add(subject);
        _context.Classes.Add(cls);

        if (withGrade)
        {
            var load = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = _student, ClassID = cls.ClassID, LoadStatus = 2 };
            _context.StudyLoads.Add(load);
            _context.Grades.Add(new Grade
            {
                GradeID = Guid.NewGuid(), StudyLoadID = load.StudyLoadID,
                MidtermGrade = 2.0m, FinalGrade = 2.25m, Remarks = 1,
                SubmittedByUserID = _teacher, DateSubmitted = DateTime.UtcNow,
            });
            _studyLoadId = load.StudyLoadID;
        }
        return cls.ClassID;
    }

    public void Dispose() => _context.Dispose();

    private Task<List<Api.DTOs.Grading.GradeResponseDto>> AsStudent() =>
        _grades.GetByStudentIdAsync(_student, _termId, _student, RoleUtils.Student);

    // ── A term that has not been released ───────────────────────────────────

    [Fact]
    public async Task AnUnreleasedTerm_ShowsTheStudentNothing_EvenWhenCleared()
    {
        Assert.Empty(await AsStudent());
    }

    [Fact]
    public async Task ReleasingTheTerm_LetsAClearedStudentSeeTheirMarks()
    {
        await _terms.SetGradesReleasedAsync(_termId, true, _registrar);

        var grades = await AsStudent();
        Assert.Equal(2.25m, Assert.Single(grades).FinalGrade);
    }

    [Fact]
    public async Task WithholdingItAgain_TakesThemBackOutOfSight()
    {
        await _terms.SetGradesReleasedAsync(_termId, true, _registrar);
        Assert.NotEmpty(await AsStudent());

        await _terms.SetGradesReleasedAsync(_termId, false, _registrar);

        Assert.Empty(await AsStudent());
    }

    [Fact]
    public async Task AReleasedTerm_StillHidesTheMarksOfAStudentWhoIsNotCleared()
    {
        await _terms.SetGradesReleasedAsync(_termId, true, _registrar);
        _clearance.Setup(c => c.IsClearedAsync(It.IsAny<Guid>(), It.IsAny<Guid>())).ReturnsAsync(false);

        // Release and clearance are separate gates; passing one is not passing the other.
        Assert.Empty(await AsStudent());
    }

    [Fact]
    public async Task AStudentReadingOneGradeDirectly_IsToldItIsNotReleasedYet()
    {
        var refused = await Assert.ThrowsAsync<UnauthorizedAccessException>(
            () => _grades.GetByStudyLoadIdAsync(_studyLoadId, _student, RoleUtils.Student));

        // Not "pending clearance": that sends them to the Registrar's door for nothing.
        Assert.Contains("not been released", refused.Message);
        Assert.DoesNotContain("clearance", refused.Message);
    }

    [Fact]
    public async Task StaffCanAlwaysSeeTheMarks_ReleasedOrNot()
    {
        var asRegistrar = await _grades.GetByStudentIdAsync(_student, _termId, _registrar, RoleUtils.Registrar);

        Assert.Single(asRegistrar);
    }

    [Fact]
    public async Task ReleasingRecordsWhenAndByWhom()
    {
        var dto = await _terms.SetGradesReleasedAsync(_termId, true, _registrar);

        Assert.True(dto.AreGradesReleased);
        Assert.NotNull(dto.GradesReleasedAt);
        var term = await _context.AcademicTerms.AsNoTracking().FirstAsync(t => t.TermID == _termId);
        Assert.Equal(_registrar, term.GradesReleasedByUserID);
    }

    [Fact]
    public async Task WithholdingClearsWhoReleasedIt()
    {
        await _terms.SetGradesReleasedAsync(_termId, true, _registrar);
        await _terms.SetGradesReleasedAsync(_termId, false, _registrar);

        var term = await _context.AcademicTerms.AsNoTracking().FirstAsync(t => t.TermID == _termId);
        Assert.Null(term.GradesReleasedAt);
        Assert.Null(term.GradesReleasedByUserID);
    }

    // ── Verifying a sheet ───────────────────────────────────────────────────

    [Fact]
    public async Task AProgramHeadVerifiesTheirOwnProgrammesSheet()
    {
        var (cls, wasVerified) = await _classes.SetVerifiedAsync(_classId, true, _programHead, RoleUtils.ProgramHead);

        Assert.False(wasVerified);
        var saved = await _context.Classes.AsNoTracking().FirstAsync(c => c.ClassID == _classId);
        Assert.NotNull(saved.VerifiedAt);
        Assert.Equal(_programHead, saved.VerifiedByUserID);
        Assert.Equal(_classId, cls.ClassID);
    }

    [Fact]
    public async Task AProgramHeadCannotVerifyAnotherProgrammesSheet()
    {
        var refused = await Assert.ThrowsAsync<UnauthorizedAccessException>(
            () => _classes.SetVerifiedAsync(_classId, true, _otherProgramHead, RoleUtils.ProgramHead));

        Assert.Contains("their own programme", refused.Message);
        Assert.Null((await _context.Classes.AsNoTracking().FirstAsync(c => c.ClassID == _classId)).VerifiedAt);
    }

    [Fact]
    public async Task ACollegeHeadIsNotNarrowedToOneProgramme()
    {
        await _classes.SetVerifiedAsync(_otherProgramClassId, true, _collegeHead, RoleUtils.CollegeHead);

        Assert.NotNull((await _context.Classes.AsNoTracking()
            .FirstAsync(c => c.ClassID == _otherProgramClassId)).VerifiedAt);
    }

    [Fact]
    public async Task TakingTheVerificationOff_ClearsWhoCheckedIt()
    {
        await _classes.SetVerifiedAsync(_classId, true, _programHead, RoleUtils.ProgramHead);

        var (_, wasVerified) = await _classes.SetVerifiedAsync(_classId, false, _programHead, RoleUtils.ProgramHead);

        Assert.True(wasVerified);
        var saved = await _context.Classes.AsNoTracking().FirstAsync(c => c.ClassID == _classId);
        Assert.Null(saved.VerifiedAt);
        Assert.Null(saved.VerifiedByUserID);
    }

    [Fact]
    public async Task VerifyingDoesNotByItselfShowAnythingToAStudent()
    {
        await _classes.SetVerifiedAsync(_classId, true, _programHead, RoleUtils.ProgramHead);

        // Checked is not the same as published. Releasing the term is what students see.
        Assert.Empty(await AsStudent());
    }

    // ── Unverified sheets warn, they do not block ───────────────────────────

    [Fact]
    public async Task ReleasingCountsTheSheetsNobodyChecked()
    {
        var dto = await _terms.SetGradesReleasedAsync(_termId, true, _registrar);

        Assert.Equal(2, dto.UnverifiedSheets);
        // Counted, but the release still happened: one unchecked class must not hold up a term.
        Assert.True(dto.AreGradesReleased);
    }

    [Fact]
    public async Task OnceEverySheetIsVerified_NothingIsFlagged()
    {
        await _classes.SetVerifiedAsync(_classId, true, _programHead, RoleUtils.ProgramHead);
        await _classes.SetVerifiedAsync(_otherProgramClassId, true, _collegeHead, RoleUtils.CollegeHead);

        var dto = await _terms.SetGradesReleasedAsync(_termId, true, _registrar);

        Assert.Equal(0, dto.UnverifiedSheets);
    }

    // ── Through the endpoints, where both are logged ────────────────────────

    private (AcademicTermsController Terms, ClassesController Classes, FakeActivityLog Log) Endpoints(Guid caller, int role)
    {
        var log = new FakeActivityLog();
        DefaultHttpContext Http()
        {
            var http = new DefaultHttpContext();
            http.Items["user_id"] = caller;
            http.Items["role"] = role;
            http.RequestServices = new OneService(log.Service);
            return http;
        }
        var terms = new AcademicTermsController(_terms)
        { ControllerContext = new ControllerContext { HttpContext = Http() } };
        var classes = new ClassesController(
            _classes,
            new Mock<IClassScheduleService>().Object,
            new Mock<IProgramScopingService>().Object,
            new ClassRepository(_context),
            new Mock<ISubjectRepository>().Object,
            new UserDetailsRepository(_context))
        { ControllerContext = new ControllerContext { HttpContext = Http() } };
        return (terms, classes, log);
    }

    private sealed class OneService : IServiceProvider
    {
        private readonly IActivityLogService _log;
        public OneService(IActivityLogService log) => _log = log;
        public object? GetService(Type t) => t == typeof(IActivityLogService) ? _log : null;
    }

    [Fact]
    public async Task ReleasingIsLogged_WithHowManySheetsWereUnchecked()
    {
        var (terms, _, log) = Endpoints(_registrar, RoleUtils.Registrar);

        var result = await terms.SetGradeRelease(_termId, new SetGradeReleaseDto { Released = true });

        Assert.IsType<OkObjectResult>(result);
        var entry = Assert.Single(log.Of(ActivityActions.GradesReleased));
        Assert.Contains("Released grades for 2026-2027", entry.Summary);
        Assert.Contains("2 sheet(s) had not been verified", entry.Summary);
    }

    [Fact]
    public async Task VerifyingIsLogged_AndASecondIdenticalSaveIsNot()
    {
        var (_, classes, log) = Endpoints(_programHead, RoleUtils.ProgramHead);

        await classes.SetVerification(_classId, new SetVerificationDto { Verified = true });
        await classes.SetVerification(_classId, new SetVerificationDto { Verified = true });

        // The second changed nothing; one entry, not two.
        var entry = Assert.Single(log.Of(ActivityActions.GradeSheetVerified));
        Assert.Contains("Verified the grade sheet", entry.Summary);
    }

    [Fact]
    public async Task AProgramHeadReachingIntoAnotherProgramme_Gets403()
    {
        var (_, classes, log) = Endpoints(_otherProgramHead, RoleUtils.ProgramHead);

        var result = await classes.SetVerification(_classId, new SetVerificationDto { Verified = true });

        var status = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, status.StatusCode);
        Assert.Empty(log.Of(ActivityActions.GradeSheetVerified));
    }

    [Fact]
    public void BothActionsAreInTheRegistryTheActivityScreenReadsFrom()
    {
        Assert.Contains(ActivityActions.GradesReleased, ActivityActions.All);
        Assert.Contains(ActivityActions.GradeSheetVerified, ActivityActions.All);
    }
}
