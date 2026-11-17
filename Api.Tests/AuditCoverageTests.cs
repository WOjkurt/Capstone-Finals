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
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

/// Actions that used to leave no trace at all: entering a grade, and changing
/// or creating a staff account.
public class AuditCoverageTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly ActivityLogService _log;
    private readonly Guid _admin = Guid.NewGuid();
    private readonly Guid _teacher = Guid.NewGuid();
    private readonly Guid _student = Guid.NewGuid();
    private readonly Guid _staff = Guid.NewGuid();
    private readonly Guid _term = Guid.NewGuid();
    private readonly Guid _classId = Guid.NewGuid();
    private readonly Guid _studyLoadId = Guid.NewGuid();

    public AuditCoverageTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _log = new ActivityLogService(_context, NullLogger<ActivityLogService>.Instance);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _term, SchoolYear = "2026-2027", Semester = 1, IsActive = true });
        _context.Users.AddRange(
            new User { UserID = _admin, FirebaseUID = "a", Email = "a@x.com", Role = RoleUtils.Admin, IsActive = true },
            new User { UserID = _teacher, FirebaseUID = "t", Email = "t@x.com", Role = RoleUtils.Teacher, IsActive = true },
            new User { UserID = _student, FirebaseUID = "s", Email = "s@x.com", Role = RoleUtils.Student, IsActive = true },
            new User { UserID = _staff, FirebaseUID = "f", Email = "f@x.com", Role = RoleUtils.Teacher, IsActive = true });
        _context.UserDetails.AddRange(
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _admin, Firstname = "Al", Lastname = "Admin" },
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _teacher, Firstname = "Ben", Lastname = "Teach" },
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _student, Firstname = "Ana", Lastname = "Cruz", ProgramID = 1, YearLevel = 1 },
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _staff, Firstname = "Dina", Lastname = "Santos" });

        var subject = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = "IT 101",
            SubjectTitle = "Intro to Computing",
            LecUnits = 3,
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
        };
        _context.Subjects.Add(subject);
        _context.Classes.Add(new Class
        {
            ClassID = _classId,
            SubjectID = subject.SubjectID,
            TermID = _term,
            ClassName = "BSIT 1A",
            UserID = _teacher,
            CreatedAt = DateTime.UtcNow,
        });
        _context.StudyLoads.Add(new StudyLoad
        {
            StudyLoadID = _studyLoadId,
            UserID = _student,
            ClassID = _classId,
            LoadStatus = StudyLoadStatus.Enrolled,
        });
        _context.SaveChanges();
    }

    private T WithLog<T>(T controller, Guid actor, int role) where T : ControllerBase
    {
        var http = new DefaultHttpContext
        {
            RequestServices = new ServiceCollection()
                .AddSingleton<IActivityLogService>(_log)
                .BuildServiceProvider()
        };
        http.Items["user_id"] = actor;
        http.Items["role"] = role;
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        return controller;
    }

    private Task<List<ActivityLog>> Entries(string action) =>
        _context.ActivityLogs.AsNoTracking().Where(l => l.Action == action).ToListAsync();

    private GradesController GradesController()
    {
        var clearance = new Mock<IGradeClearanceService>();
        clearance.Setup(c => c.IsClearedAsync(It.IsAny<Guid>(), It.IsAny<Guid>())).ReturnsAsync(true);
        var service = new GradeService(_context, new GradeRepository(_context), clearance.Object,
            new Mock<IProgramScopingService>().Object);
        return WithLog(new GradesController(service), _teacher, RoleUtils.Teacher);
    }

    [Fact]
    public async Task Submitting_a_grade_is_written_to_the_activity_log()
    {
        var controller = GradesController();

        await controller.SubmitGrade(new SubmitGradeDto
        {
            StudyLoadId = _studyLoadId,
            MidtermGrade = 1.75m,
        });

        var entry = Assert.Single(await Entries(ActivityActions.GradeSubmitted));
        Assert.Equal(_teacher, entry.ActorUserID);
        Assert.Equal(_student, entry.StudentUserID);
        Assert.Equal(_term, entry.TermID);
        Assert.Contains("IT 101", entry.Summary);
        Assert.Contains("midterm 1.75", entry.Summary);
    }

    [Fact]
    public async Task A_batch_writes_one_entry_per_student()
    {
        var second = Guid.NewGuid();
        var otherStudent = Guid.NewGuid();
        _context.Users.Add(new User { UserID = otherStudent, FirebaseUID = "s2", Email = "s2@x.com", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = otherStudent, Firstname = "Mark", Lastname = "Reyes", ProgramID = 1, YearLevel = 1 });
        _context.StudyLoads.Add(new StudyLoad
        {
            StudyLoadID = second,
            UserID = otherStudent,
            ClassID = _classId,
            LoadStatus = StudyLoadStatus.Enrolled,
        });
        await _context.SaveChangesAsync();

        var controller = GradesController();
        await controller.SubmitGradeBatch(new SubmitGradeBatchDto
        {
            ClassId = _classId,
            Grades = new List<SubmitGradeBatchItemDto>
            {
                new() { StudyLoadId = _studyLoadId, FinalGrade = 2.00m },
                new() { StudyLoadId = second, FinalGrade = 2.25m },
            },
        });

        var entries = await Entries(ActivityActions.GradeSubmitted);
        Assert.Equal(2, entries.Count);
        Assert.Contains(entries, e => e.StudentUserID == _student);
        Assert.Contains(entries, e => e.StudentUserID == otherStudent);
        Assert.All(entries, e => Assert.Contains("final", e.Summary));
    }

    [Fact]
    public async Task A_failed_grade_submission_logs_nothing()
    {
        var controller = GradesController();

        // 9.9 is off the DBTC scale, so the submission is refused.
        await controller.SubmitGrade(new SubmitGradeDto
        {
            StudyLoadId = _studyLoadId,
            MidtermGrade = 9.9m,
        });

        Assert.Empty(await Entries(ActivityActions.GradeSubmitted));
    }

    [Fact]
    public async Task Describing_staff_reads_the_role_before_a_change()
    {
        var before = await _log.DescribeStaffAsync(_staff);

        Assert.NotNull(before);
        Assert.Equal(RoleUtils.Teacher, before!.Value.Role);
        Assert.True(before.Value.IsActive);
        Assert.Contains("Dina", before.Value.Name);
    }

    [Fact]
    public async Task Describing_an_unknown_account_returns_null()
    {
        Assert.Null(await _log.DescribeStaffAsync(Guid.NewGuid()));
    }

    [Fact]
    public async Task A_role_change_records_the_old_and_new_role()
    {
        // What the controller does around the service call.
        var before = await _log.DescribeStaffAsync(_staff);
        var user = await _context.Users.FirstAsync(u => u.UserID == _staff);
        user.Role = RoleUtils.Registrar;
        await _context.SaveChangesAsync();

        await _log.LogAsync(_admin, ActivityActions.RoleChanged,
            $"Dina Santos (f@x.com): {RoleUtils.GetRoleName(before!.Value.Role)} -> {RoleUtils.GetRoleName(user.Role)}",
            _staff);

        var entry = Assert.Single(await Entries(ActivityActions.RoleChanged));
        Assert.Equal(_admin, entry.ActorUserID);
        Assert.Equal(_staff, entry.StudentUserID);
        Assert.Contains("Teacher", entry.Summary);
        Assert.Contains("Registrar", entry.Summary);
    }

    [Fact]
    public void Every_new_action_is_listed_for_the_activity_log_filter()
    {
        foreach (var action in new[]
                 {
                     ActivityActions.GradeSubmitted,
                     ActivityActions.StaffCreated,
                     ActivityActions.RoleChanged,
                     ActivityActions.AccountDisabled,
                     ActivityActions.AccountReactivated,
                     ActivityActions.ApplicationApproved,
                     ActivityActions.ApplicationRejected,
                     ActivityActions.AccountLinked,
                 })
        {
            Assert.Contains(action, ActivityActions.All);
        }
    }

    public void Dispose() => _context.Dispose();
}
