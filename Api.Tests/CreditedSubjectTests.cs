using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.Credits;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

// Subjects credited from another school count as passed everywhere.
public class CreditedSubjectTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly CreditedSubjectService _credits;
    private readonly StudyLoadService _studyLoads;
    private readonly Guid _studentId = Guid.NewGuid();
    private readonly Guid _registrarId = Guid.NewGuid();
    private readonly Guid _termId = Guid.NewGuid();
    private readonly Dictionary<string, Subject> _s = new();

    public CreditedSubjectTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _credits = new CreditedSubjectService(_context);
        var clearance = new Mock<IGradeClearanceService>();
        clearance.Setup(c => c.IsClearedAsync(It.IsAny<Guid>(), It.IsAny<Guid>())).ReturnsAsync(true);
        _studyLoads = new StudyLoadService(_context, new StudyLoadRepository(_context), clearance.Object, NullLogger<StudyLoadService>.Instance);

        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" },
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSME", ProgramName = "BS ME" });
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _termId, SchoolYear = "2026-2027", Semester = 2, IsActive = true });
        _context.Users.AddRange(
            new User { UserID = _studentId, FirebaseUID = "fb-s", Email = "s@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true },
            new User { UserID = _registrarId, FirebaseUID = "fb-r", Email = "r@dbtc-cebu.edu.ph", Role = RoleUtils.Registrar, IsActive = true });
        _context.UserDetails.AddRange(
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _studentId, Firstname = "Tina", Lastname = "Transfer", ProgramID = 1, YearLevel = 1 },
            new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _registrarId, Firstname = "Rita", Lastname = "Registrar" });

        AddSubject("IT 101", 1, 1, 1);
        AddSubject("IT 102", 1, 1, 2); // needs IT 101
        AddSubject("GEC 101", 1, 1, 1);
        AddSubject("ME 101", 2, 1, 1);
        AddSubject("IT 201", 1, 2, 1);
        _context.SubjectPrerequisites.Add(new SubjectPrerequisite
        {
            SubjectID = _s["IT 102"].SubjectID, PrerequisiteSubjectID = _s["IT 101"].SubjectID, RequisiteType = Api.Constants.RequisiteTypeConstants.Prerequisite, PrerequisiteID = Guid.NewGuid()
        });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void AddSubject(string code, int program, int year, int sem)
    {
        var s = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code, LecUnits = 3, ProgramID = program, YearLevel = year, DefaultSemester = sem };
        _s[code] = s;
        _context.Subjects.Add(s);
    }

    private Task<CreditedSubjectDto> Credit(string code, string school = "  Cebu Tech  ") =>
        _credits.CreateAsync(new CreateCreditedSubjectDto
        {
            UserId = _studentId, SubjectId = _s[code].SubjectID, SourceSchool = school, SourceSubjectCode = "CS1", Grade = "1.75", SchoolYear = "2025-2026"
        }, _registrarId);

    private async Task Took(string code, int status, int? remarks)
    {
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = _s[code].SubjectID, TermID = _termId, ClassName = "BSIT 1A", CreatedAt = DateTime.UtcNow };
        var load = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = _studentId, ClassID = cls.ClassID, LoadStatus = status, CreatedAt = DateTime.UtcNow };
        _context.Classes.Add(cls);
        _context.StudyLoads.Add(load);
        if (remarks.HasValue)
            _context.Grades.Add(new Grade { GradeID = Guid.NewGuid(), StudyLoadID = load.StudyLoadID, FinalGrade = remarks == 1 ? 2m : 5m, Remarks = remarks, SubmittedByUserID = _registrarId });
        await _context.SaveChangesAsync();
    }

    [Fact]
    public async Task Create_SavesTrimmedDetails_AndRecorder()
    {
        var dto = await Credit("IT 101");

        Assert.Equal("IT 101", dto.SubjectCode);
        Assert.Equal("Cebu Tech", dto.SourceSchool);
        Assert.Equal("1.75", dto.Grade);
        Assert.Equal(3m, dto.Units);
        Assert.Equal("Rita Registrar", dto.RecordedBy);
        Assert.Single(await _credits.GetByStudentAsync(_studentId));
    }

    [Fact]
    public async Task Create_RejectsBlankSchool_OtherProgram_AndDuplicates()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() => Credit("IT 101", "  "));
        var other = await Assert.ThrowsAsync<InvalidOperationException>(() => Credit("ME 101"));
        Assert.Contains("not in the student's program", other.Message);

        await Credit("IT 101");
        var dup = await Assert.ThrowsAsync<InvalidOperationException>(() => Credit("IT 101"));
        Assert.Contains("already credited", dup.Message);
    }

    [Fact]
    public async Task Create_RejectsSubjectPassedOrInProgressAtDbtc()
    {
        await Took("IT 101", StudyLoadStatus.Enrolled, 1);
        Assert.Contains("already passed", (await Assert.ThrowsAsync<InvalidOperationException>(() => Credit("IT 101"))).Message);

        await Took("GEC 101", StudyLoadStatus.Pending, null);
        Assert.Contains("currently taking", (await Assert.ThrowsAsync<InvalidOperationException>(() => Credit("GEC 101"))).Message);
    }

    [Fact]
    public async Task Create_AllowsSubjectFailedAtDbtc()
    {
        await Took("IT 101", StudyLoadStatus.Enrolled, 2);

        var dto = await Credit("IT 101");

        Assert.Equal("IT 101", dto.SubjectCode);
    }

    [Fact]
    public async Task Credit_SatisfiesPrerequisite_InProposedBlock()
    {
        await Credit("IT 101");

        var block = await _studyLoads.GetProposedBlockAsync(_studentId, _termId);

        var it102 = block.Single(b => b.SubjectCode == "IT 102");
        Assert.Empty(it102.PrerequisiteMessages);
        Assert.DoesNotContain(block, b => b.SubjectCode == "IT 101" && b.Category != "regular");
    }

    [Fact]
    public async Task Credit_ResolvesAnEarlierFailure_AndCountsForYearLevel()
    {
        await Took("IT 101", StudyLoadStatus.Enrolled, 2);
        await Credit("IT 101");
        await Credit("GEC 101");
        await Took("IT 102", StudyLoadStatus.Enrolled, 1);

        var block = await _studyLoads.GetProposedBlockAsync(_studentId, _termId);
        Assert.DoesNotContain(block, b => b.Category == "retake");

        var suggestion = await _studyLoads.GetYearLevelSuggestionAsync(_studentId);
        Assert.Equal(9m, suggestion.PassedUnits);
        Assert.Equal(2, suggestion.SuggestedYearLevel);
    }

    [Fact]
    public async Task Delete_RemovesTheCredit()
    {
        var dto = await Credit("IT 101");

        await _credits.DeleteAsync(dto.CreditedSubjectId);

        Assert.Empty(await _credits.GetByStudentAsync(_studentId));
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _credits.DeleteAsync(dto.CreditedSubjectId));
    }

    [Fact]
    public async Task Controller_MapsErrors_AndUsesCallerAsRecorder()
    {
        var controller = new CreditedSubjectsController(_credits);
        var http = new DefaultHttpContext();
        http.Items["user_id"] = _registrarId;
        controller.ControllerContext = new ControllerContext { HttpContext = http };

        var ok = await controller.Create(new CreateCreditedSubjectDto { UserId = _studentId, SubjectId = _s["IT 101"].SubjectID, SourceSchool = "Cebu Tech" });
        Assert.IsType<OkObjectResult>(ok);
        Assert.IsType<BadRequestObjectResult>(await controller.Create(new CreateCreditedSubjectDto { UserId = _studentId, SubjectId = _s["IT 101"].SubjectID, SourceSchool = "Cebu Tech" }));
        Assert.IsType<NotFoundObjectResult>(await controller.Create(new CreateCreditedSubjectDto { UserId = Guid.NewGuid(), SubjectId = _s["IT 101"].SubjectID, SourceSchool = "X" }));
        Assert.IsType<NotFoundObjectResult>(await controller.Delete(Guid.NewGuid()));
    }

    [Fact]
    public void Endpoints_HaveTheRightRoles()
    {
        var t = typeof(CreditedSubjectsController);
        Assert.NotEmpty(t.GetMethod(nameof(CreditedSubjectsController.GetByStudent))!.GetCustomAttributes(typeof(RequireRegistrarCollegeHeadOrAdminAttribute), false));
        Assert.NotEmpty(t.GetMethod(nameof(CreditedSubjectsController.Create))!.GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), false));
        Assert.NotEmpty(t.GetMethod(nameof(CreditedSubjectsController.Delete))!.GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), false));
    }
}
