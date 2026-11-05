using Api.Auth;
using Api.Controllers;
using Api.Domain.Audit;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Credits;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

// Staff actions are written to the activity log; logging never breaks the action.
public class ActivityLogTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly ActivityLogService _log;
    private readonly StudyLoadService _studyLoads;
    private readonly Guid _registrar = Guid.NewGuid();
    private readonly Guid _student = Guid.NewGuid();
    private readonly Guid _term = Guid.NewGuid();
    private readonly Dictionary<string, Subject> _s = new();

    public ActivityLogTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _log = new ActivityLogService(_context, NullLogger<ActivityLogService>.Instance);
        var clearance = new Mock<IGradeClearanceService>();
        clearance.Setup(c => c.IsClearedAsync(It.IsAny<Guid>(), It.IsAny<Guid>())).ReturnsAsync(true);
        _studyLoads = new StudyLoadService(_context, new StudyLoadRepository(_context), clearance.Object, NullLogger<StudyLoadService>.Instance);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _term, SchoolYear = "2026-2027", Semester = 1, IsActive = true });
        _context.Users.AddRange(
            new User { UserID = _registrar, FirebaseUID = "r", Email = "r@x.com", Role = RoleUtils.Registrar, IsActive = true },
            new User { UserID = _student, FirebaseUID = "s", Email = "s@x.com", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.AddRange(
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _registrar, Firstname = "Rita", Lastname = "Reg" },
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _student, Firstname = "Ana", Lastname = "Cruz", ProgramID = 1, YearLevel = 1 });
        foreach (var code in new[] { "IT 101", "IT 102", "IT 103" })
        {
            var subject = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code, LecUnits = 3, ProgramID = 1, YearLevel = 1, DefaultSemester = 1 };
            _s[code] = subject;
            _context.Subjects.Add(subject);
        }
        _context.Subjects.Add(new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT 201", SubjectTitle = "x", LecUnits = 3, ProgramID = 1, YearLevel = 2, DefaultSemester = 1 });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private T WithLog<T>(T controller) where T : ControllerBase
    {
        var http = new DefaultHttpContext
        {
            RequestServices = new ServiceCollection()
                .AddSingleton<IActivityLogService>(_log)
                .AddSingleton<IStudyLoadChangeService>(new StudyLoadChangeService(_context))
                .BuildServiceProvider()
        };
        http.Items["user_id"] = _registrar;
        http.Items["role"] = RoleUtils.Registrar;
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        return controller;
    }

    private StudyLoadsController StudyLoadsController() =>
        WithLog(new StudyLoadsController(_studyLoads, new ClassRepository(_context), new UserDetailsRepository(_context), new Mock<IProgramScopingService>().Object));

    private async Task<Guid> OpenClass(string code)
    {
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = _s[code].SubjectID, TermID = _term, ClassName = "BSIT 1A", CreatedAt = DateTime.UtcNow };
        _context.Classes.Add(cls);
        await _context.SaveChangesAsync();
        return cls.ClassID;
    }

    private Task<List<ActivityLog>> Entries() => _context.ActivityLogs.AsNoTracking().OrderBy(l => l.OccurredAt).ToListAsync();

    [Fact]
    public async Task LogAsync_StoresNamesRoleAndTerm()
    {
        await _log.LogAsync(_registrar, ActivityActions.ClearanceChanged, "Marked grades as cleared", _student, _term);

        var e = Assert.Single(await Entries());
        Assert.Equal(("Rita Reg", RoleUtils.Registrar, "Ana Cruz", _term), (e.ActorName, e.ActorRole, e.StudentName, e.TermID));
    }

    [Fact]
    public async Task LogAsync_NeverThrows()
    {
        var context = new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var log = new ActivityLogService(context, NullLogger<ActivityLogService>.Instance);
        context.Dispose();

        await log.LogAsync(_registrar, ActivityActions.LoadsSaved, "x");
    }

    [Fact]
    public async Task SavingOverTheLimit_LogsTheSaveAndTheOverload()
    {
        // Year 1 Sem 1 curriculum is 9 units; four classes would be 12, so add a 4th subject's class.
        var ids = new List<Guid> { await OpenClass("IT 101"), await OpenClass("IT 102"), await OpenClass("IT 103") };
        _context.Subjects.Add(new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "GEC 1", SubjectTitle = "g", LecUnits = 3, ProgramID = 1, YearLevel = 2, DefaultSemester = 2 });
        await _context.SaveChangesAsync();
        _s["GEC 1"] = await _context.Subjects.FirstAsync(s => s.SubjectCode == "GEC 1");
        ids.Add(await OpenClass("GEC 1"));

        var result = await StudyLoadsController().EnrollBatch(new EnrollBatchRequestDto
        {
            UserId = _student, TermId = _term, ClassIds = ids, AsPending = true, OverloadReason = "Catching up"
        });

        Assert.IsType<OkObjectResult>(result);
        var entries = await Entries();
        Assert.Equal(new[] { ActivityActions.LoadsSaved, ActivityActions.OverloadApproved }, entries.Select(e => e.Action));
        Assert.Equal("Saved 4 subject(s) as Pending", entries[0].Summary);
        Assert.Equal("Approved overload 12 of 9 units: Catching up", entries[1].Summary);
        Assert.All(entries, e => Assert.Equal(_student, e.StudentUserID));
    }

    [Fact]
    public async Task AddingAfterEnrollment_NeedsAReason_AndIsRecorded()
    {
        var controller = StudyLoadsController();
        // First enrollment for the term: no reason needed, nothing recorded as an add.
        Assert.IsType<OkObjectResult>(await controller.EnrollBatch(new EnrollBatchRequestDto { UserId = _student, TermId = _term, ClassIds = { await OpenClass("IT 101") } }));
        Assert.Empty(_context.StudyLoadChanges);

        var it102 = await OpenClass("IT 102");
        var refused = Assert.IsType<BadRequestObjectResult>(await controller.EnrollBatch(new EnrollBatchRequestDto { UserId = _student, TermId = _term, ClassIds = { it102 } }));
        Assert.Contains("reason", refused.Value!.ToString()!);
        Assert.IsType<BadRequestObjectResult>(await controller.EnrollSingle(new EnrollSingleRequestDto { UserId = _student, ClassId = it102 }));

        Assert.IsType<OkObjectResult>(await controller.EnrollBatch(new EnrollBatchRequestDto { UserId = _student, TermId = _term, ClassIds = { it102 }, ChangeReason = "Late add, approved" }));
        Assert.IsType<OkObjectResult>(await controller.EnrollSingle(new EnrollSingleRequestDto { UserId = _student, ClassId = await OpenClass("IT 103"), ChangeReason = "Retake" }));
        // Asking again for a class the student already has is not a new add.
        Assert.IsType<OkObjectResult>(await controller.EnrollSingle(new EnrollSingleRequestDto { UserId = _student, ClassId = it102, ChangeReason = "again" }));

        var changes = Assert.IsType<List<StudyLoadChangeDto>>(Assert.IsType<OkObjectResult>(await controller.GetChanges(_student, _term)).Value);
        Assert.Equal(new[] { ("Added", "IT 102", "Late add, approved"), ("Added", "IT 103", "Retake") },
            changes.Select(c => (c.Kind, c.SubjectCode, c.Reason)));
        Assert.All(changes, c => Assert.Equal("Rita Reg", c.ChangedBy));
        Assert.Contains(await Entries(), e => e.Summary == "Added 1 subject(s) after enrollment: Late add, approved");
    }

    [Fact]
    public async Task DropAndWithdraw_NeedAReason_AndReenrollIsRecorded()
    {
        var controller = StudyLoadsController();
        await controller.EnrollBatch(new EnrollBatchRequestDto { UserId = _student, TermId = _term, ClassIds = { await OpenClass("IT 101"), await OpenClass("IT 102") } });
        var loads = await _context.StudyLoads.AsNoTracking().ToListAsync();

        Assert.IsType<BadRequestObjectResult>(await controller.UpdateStatus(loads[0].StudyLoadID, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Dropped, Reason = "  " }));
        Assert.IsType<BadRequestObjectResult>(await controller.UpdateStatus(loads[1].StudyLoadID, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Withdrawn }));
        Assert.Equal(StudyLoadStatus.Enrolled, (await _context.StudyLoads.AsNoTracking().FirstAsync(l => l.StudyLoadID == loads[0].StudyLoadID)).LoadStatus);

        await controller.UpdateStatus(loads[0].StudyLoadID, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Dropped, Reason = "Schedule conflict" });
        await controller.UpdateStatus(loads[1].StudyLoadID, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Withdrawn, Reason = "Medical" });
        await controller.UpdateStatus(loads[0].StudyLoadID, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Enrolled });

        var changes = await new StudyLoadChangeService(_context).GetAsync(_student, _term);
        Assert.Equal(new[] { ("Dropped", "Schedule conflict"), ("Withdrawn", "Medical"), ("Re-enrolled", (string?)null) },
            changes.Select(c => (c.Kind, c.Reason)));
    }

    [Fact]
    public async Task FinalizeAndDrop_AreLogged()
    {
        var classId = await OpenClass("IT 101");
        var controller = StudyLoadsController();
        await controller.EnrollBatch(new EnrollBatchRequestDto { UserId = _student, TermId = _term, ClassIds = { classId }, AsPending = true });
        var loadId = (await _context.StudyLoads.FirstAsync()).StudyLoadID;

        Assert.IsType<OkObjectResult>(await controller.FinalizeBatch(new FinalizeStudyLoadsRequestDto { UserId = _student, TermId = _term }));
        Assert.IsType<OkObjectResult>(await controller.UpdateStatus(loadId, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Dropped, Reason = "Schedule conflict" }));

        var entries = await Entries();
        Assert.Equal("Finalized 1 subject(s): IT 101", entries.Single(e => e.Action == ActivityActions.LoadsFinalized).Summary);
        Assert.Equal("IT 101 (BSIT 1A): Enrolled -> Dropped (Schedule conflict)", entries.Single(e => e.Action == ActivityActions.LoadStatusChanged).Summary);
    }

    [Fact]
    public async Task BulkYearLevels_LogOldAndNewPerStudent()
    {
        await StudyLoadsController().ApplyYearLevels(new ApplyYearLevelsRequestDto
        {
            Changes = { new YearLevelChangeDto { UserId = _student, YearLevel = 2 } }
        });

        var e = Assert.Single(await Entries());
        Assert.Equal(ActivityActions.YearLevelChanged, e.Action);
        Assert.Equal("Year level 1 -> 2 (Promotion page)", e.Summary);
    }

    [Fact]
    public async Task Credits_AddAndRemove_AreLogged()
    {
        var controller = WithLog(new CreditedSubjectsController(new CreditedSubjectService(_context)));

        var ok = Assert.IsType<OkObjectResult>(await controller.Create(new CreateCreditedSubjectDto
        {
            UserId = _student, SubjectId = _s["IT 101"].SubjectID, SourceSchool = "Cebu Tech", Grade = "1.5"
        }));
        await controller.Delete(((CreditedSubjectDto)ok.Value!).CreditedSubjectId);

        var entries = await Entries();
        Assert.Equal("Credited IT 101 from Cebu Tech (grade 1.5)", entries[0].Summary);
        Assert.Equal("Removed credit for IT 101 from Cebu Tech", entries[1].Summary);
    }

    [Fact]
    public async Task Search_FiltersPagesAndNewestFirst()
    {
        for (int i = 0; i < 5; i++)
        {
            await _log.LogAsync(_registrar, i % 2 == 0 ? ActivityActions.LoadsSaved : ActivityActions.CreditAdded, $"entry {i}", _student, _term);
        }
        await _log.LogAsync(_registrar, ActivityActions.TeacherAssigned, "no student");

        var page1 = await _log.SearchAsync(null, null, null, null, null, 1, 4);
        Assert.Equal(6, page1.TotalCount);
        Assert.Equal(4, page1.Items.Count);
        Assert.Equal("no student", page1.Items[0].Summary);

        var credits = await _log.SearchAsync(null, null, ActivityActions.CreditAdded, _student, null, 1, 50);
        Assert.Equal(new[] { "entry 3", "entry 1" }, credits.Items.Select(i => i.Summary));
        Assert.Contains("2026-2027", credits.Items[0].TermLabel);

        var none = await _log.SearchAsync(DateTime.UtcNow.AddMinutes(1), null, null, null, null, 1, 50);
        Assert.Empty(none.Items);
    }

    [Fact]
    public async Task Endpoint_RejectsUnknownAction_AndIsRegistrarOnly()
    {
        var controller = new ActivityLogController(_log);
        Assert.IsType<BadRequestObjectResult>(await controller.Search(null, null, "NOPE", null, null));
        Assert.IsType<OkObjectResult>(await controller.Search(null, null, ActivityActions.LoadsSaved, null, null));
        Assert.NotEmpty(typeof(ActivityLogController).GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), false));
    }
}
