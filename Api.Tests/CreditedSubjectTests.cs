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
            UserId = _studentId, SubjectId = _s[code].SubjectID, SourceSchool = school, SourceSubjectCode = "CS1", Grade = "1.75", SchoolYear = "2025-2026", CreditedUnits = 3
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

    private UpdateCreditedSubjectDto Edit(CreditedSubjectDto from, string? subject = null, string? school = null,
        string? theirCode = null, string? grade = null, string? schoolYear = null, decimal? units = null,
        int? kind = null, Guid? termId = null) =>
        new()
        {
            SubjectId = subject == null ? from.SubjectId : _s[subject].SubjectID,
            SourceSchool = school ?? from.SourceSchool,
            SourceSubjectCode = theirCode ?? from.SourceSubjectCode,
            Grade = grade ?? from.Grade,
            SchoolYear = schoolYear ?? from.SchoolYear,
            CreditedUnits = units ?? from.CreditedUnits,
            Kind = kind ?? from.Kind,
            TermId = termId ?? from.TermId
        };

    [Fact]
    public async Task Update_CorrectsEveryDetail_AndKeepsTheStudentAndRecorder()
    {
        var dto = await Credit("IT 101", "Cebu Tecnological University"); // typo

        var fixedUp = await _credits.UpdateAsync(dto.CreditedSubjectId, Edit(dto,
            school: "  Cebu Technological University  ", theirCode: "CS 101", grade: "2.00",
            schoolYear: "2024-2025", units: 1.5m));

        Assert.Equal("Cebu Technological University", fixedUp.SourceSchool);
        Assert.Equal(("CS 101", "2.00", "2024-2025"), (fixedUp.SourceSubjectCode, fixedUp.Grade, fixedUp.SchoolYear));
        Assert.Equal((1.5m, 3m, true), (fixedUp.CreditedUnits, fixedUp.Units, fixedUp.IsPartial));
        // Whose credit it is, and who recorded it, are not up for correction.
        Assert.Equal((_studentId, "Rita Registrar"), (fixedUp.UserId, fixedUp.RecordedBy));
        Assert.Equal(1.5m, (await _credits.GetByStudentAsync(_studentId)).Single().CreditedUnits);
    }

    [Fact]
    public async Task Update_MovesTheCreditToAnotherSubject()
    {
        var dto = await Credit("IT 101");

        var moved = await _credits.UpdateAsync(dto.CreditedSubjectId, Edit(dto, subject: "GEC 101"));

        Assert.Equal("GEC 101", moved.SubjectCode);
        Assert.Equal("GEC 101", (await _credits.GetByStudentAsync(_studentId)).Single().SubjectCode);
        // The subject it was moved off is open to be credited again.
        Assert.Equal("IT 101", (await Credit("IT 101")).SubjectCode);
    }

    [Fact]
    public async Task Update_ChecksTheNewSubjectTheWayRecordingDoes()
    {
        var dto = await Credit("IT 101");

        var otherProgram = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _credits.UpdateAsync(dto.CreditedSubjectId, Edit(dto, subject: "ME 101")));
        Assert.Contains("not in the student's program", otherProgram.Message);

        await Took("GEC 101", StudyLoadStatus.Enrolled, 1);
        var passedHere = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _credits.UpdateAsync(dto.CreditedSubjectId, Edit(dto, subject: "GEC 101")));
        Assert.Contains("already passed GEC 101", passedHere.Message);

        await Credit("IT 201");
        var dup = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _credits.UpdateAsync(dto.CreditedSubjectId, Edit(dto, subject: "IT 201")));
        Assert.Contains("already credited", dup.Message);

        // All refused, so the credit is untouched.
        Assert.Equal("IT 101", (await _credits.GetByIdAsync(dto.CreditedSubjectId))!.SubjectCode);
    }

    [Fact]
    public async Task Update_TurnsACreditIntoACrossEnrollment_AndBack()
    {
        var dto = await Credit("IT 101");

        var crossEnrolled = await _credits.UpdateAsync(dto.CreditedSubjectId,
            Edit(dto, kind: CreditKinds.CrossEnrollment, termId: _termId));
        // A cross-enrollment's school year is the term's, whatever was typed.
        Assert.Equal((CreditKinds.CrossEnrollment, "2026-2027", "2026-2027 (2nd Sem)"),
            (crossEnrolled.Kind, crossEnrolled.SchoolYear, crossEnrolled.TermLabel));

        var noTerm = await Assert.ThrowsAsync<InvalidOperationException>(() => _credits.UpdateAsync(
            dto.CreditedSubjectId, new UpdateCreditedSubjectDto
            {
                SubjectId = dto.SubjectId, SourceSchool = "Cebu Tech", CreditedUnits = 3, Kind = CreditKinds.CrossEnrollment
            }));
        Assert.Contains("Choose the DBTC term", noTerm.Message);

        var back = await _credits.UpdateAsync(dto.CreditedSubjectId, new UpdateCreditedSubjectDto
        {
            SubjectId = dto.SubjectId, SourceSchool = "Cebu Tech", SchoolYear = "2025-2026",
            CreditedUnits = 3, Kind = CreditKinds.Transfer
        });
        Assert.Equal((CreditKinds.Transfer, "2025-2026", null), (back.Kind, back.SchoolYear, back.TermLabel));
        Assert.Null(back.TermId);
    }

    [Fact]
    public async Task Update_RejectsABlankSchool_BadUnits_AndAnUnknownCredit()
    {
        var dto = await Credit("IT 101");

        var blank = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _credits.UpdateAsync(dto.CreditedSubjectId, Edit(dto, school: "   ")));
        Assert.Contains("Enter the name of the school", blank.Message);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _credits.UpdateAsync(dto.CreditedSubjectId, Edit(dto, units: 0)));
        var tooMany = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _credits.UpdateAsync(dto.CreditedSubjectId, Edit(dto, units: 4)));
        Assert.Contains("only 3 units", tooMany.Message);

        Assert.Equal("Cebu Tech", (await _credits.GetByStudentAsync(_studentId)).Single().SourceSchool);

        await Assert.ThrowsAsync<KeyNotFoundException>(() => _credits.UpdateAsync(
            Guid.NewGuid(), new UpdateCreditedSubjectDto { SourceSchool = "Cebu Tech", CreditedUnits = 3 }));
    }

    [Fact]
    public async Task Update_UsesTheAccreditedListsSpelling_AndClearsBlankDetails()
    {
        _context.AccreditedSchools.Add(new AccreditedSchool
            { SchoolID = Guid.NewGuid(), Name = "University of San Carlos", CreatedAt = DateTime.UtcNow });
        await _context.SaveChangesAsync();
        var dto = await Credit("IT 101");

        var fixedUp = await _credits.UpdateAsync(dto.CreditedSubjectId, new UpdateCreditedSubjectDto
        {
            SubjectId = dto.SubjectId, SourceSchool = "university of  san carlos",
            SourceSubjectCode = "   ", Grade = "", SchoolYear = " ", CreditedUnits = 3
        });

        Assert.Equal("University of San Carlos", fixedUp.SourceSchool);
        Assert.Null(fixedUp.SourceSubjectCode);
        Assert.Null(fixedUp.Grade);
        Assert.Null(fixedUp.SchoolYear);
    }

    /// <summary>
    /// A correction that leaves the subject alone must not attach a second copy of that subject to the
    /// context. EF refuses to save when it does, and because the clash surfaces as an
    /// <see cref="InvalidOperationException"/> the controller turns it into "400 Bad Request" on what is
    /// only a typo fix. Checked with the subject already tracked by the context, which is what made the
    /// clash happen, and through the controller, which is where it was visible.
    /// </summary>
    [Fact]
    public async Task Update_WithoutChangingTheSubject_DoesNotClashWithTheTrackedSubject()
    {
        var dto = await Credit("IT 101");
        // Something else in the same request already has the subject loaded and tracked.
        var tracked = await _context.Subjects.FirstAsync(s => s.SubjectID == dto.SubjectId);
        Assert.Equal(EntityState.Unchanged, _context.Entry(tracked).State);

        var controller = new CreditedSubjectsController(_credits);
        var http = new DefaultHttpContext();
        http.Items["user_id"] = _registrarId;
        controller.ControllerContext = new ControllerContext { HttpContext = http };

        var ok = Assert.IsType<OkObjectResult>(
            await controller.Update(dto.CreditedSubjectId, Edit(dto, grade: "2.00", theirCode: "CS 101")));

        var corrected = (CreditedSubjectDto)ok.Value!;
        Assert.Equal(("IT 101", "2.00", "CS 101"), (corrected.SubjectCode, corrected.Grade, corrected.SourceSubjectCode));
        // No second copy of the subject was put in the context's way, and the credit still points at it.
        Assert.Same(tracked, _context.ChangeTracker.Entries<Subject>().Single(e => e.Entity.SubjectID == dto.SubjectId).Entity);
        Assert.Equal(dto.SubjectId, (await _credits.GetByStudentAsync(_studentId)).Single().SubjectId);
    }

    /// <summary>
    /// A correction that leaves the subject alone must not be trapped by something that changed since
    /// the credit was recorded — here a program shift and a DBTC load opened afterwards.
    /// </summary>
    [Fact]
    public async Task Update_OfTheDetailsOnly_SurvivesAProgramShiftAndALaterDbtcLoad()
    {
        var dto = await Credit("IT 101");
        await Took("IT 101", StudyLoadStatus.Pending, null);
        var student = await _context.UserDetails.FirstAsync(ud => ud.UserID == _studentId);
        student.ProgramID = 2;
        await _context.SaveChangesAsync();

        var fixedUp = await _credits.UpdateAsync(dto.CreditedSubjectId, Edit(dto, grade: "2.25"));

        Assert.Equal(("2.25", "IT 101"), (fixedUp.Grade, fixedUp.SubjectCode));
    }

    [Fact]
    public async Task Controller_MapsErrors_AndUsesCallerAsRecorder()
    {
        var controller = new CreditedSubjectsController(_credits);
        var http = new DefaultHttpContext();
        http.Items["user_id"] = _registrarId;
        controller.ControllerContext = new ControllerContext { HttpContext = http };

        var ok = await controller.Create(new CreateCreditedSubjectDto { UserId = _studentId, SubjectId = _s["IT 101"].SubjectID, SourceSchool = "Cebu Tech", CreditedUnits = 3 });
        Assert.IsType<OkObjectResult>(ok);
        Assert.IsType<BadRequestObjectResult>(await controller.Create(new CreateCreditedSubjectDto { UserId = _studentId, SubjectId = _s["IT 101"].SubjectID, SourceSchool = "Cebu Tech", CreditedUnits = 3 }));
        Assert.IsType<NotFoundObjectResult>(await controller.Create(new CreateCreditedSubjectDto { UserId = Guid.NewGuid(), SubjectId = _s["IT 101"].SubjectID, SourceSchool = "X", CreditedUnits = 3 }));
        Assert.IsType<NotFoundObjectResult>(await controller.Delete(Guid.NewGuid()));

        var credit = (CreditedSubjectDto)((OkObjectResult)ok).Value!;
        Assert.IsType<OkObjectResult>(await controller.Update(credit.CreditedSubjectId,
            Edit(credit, school: "Cebu Technological University")));
        Assert.IsType<BadRequestObjectResult>(await controller.Update(credit.CreditedSubjectId, Edit(credit, school: " ")));
        Assert.IsType<NotFoundObjectResult>(await controller.Update(Guid.NewGuid(), Edit(credit)));
        Assert.IsType<NotFoundObjectResult>(await controller.Update(credit.CreditedSubjectId,
            new UpdateCreditedSubjectDto { SubjectId = Guid.NewGuid(), SourceSchool = "Cebu Tech", CreditedUnits = 3 }));
    }

    [Fact]
    public void Endpoints_HaveTheRightRoles()
    {
        var t = typeof(CreditedSubjectsController);
        Assert.NotEmpty(t.GetMethod(nameof(CreditedSubjectsController.GetByStudent))!.GetCustomAttributes(typeof(RequireRegistrarCollegeHeadOrAdminAttribute), false));
        Assert.NotEmpty(t.GetMethod(nameof(CreditedSubjectsController.Create))!.GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), false));
        Assert.NotEmpty(t.GetMethod(nameof(CreditedSubjectsController.Update))!.GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), false));
        Assert.NotEmpty(t.GetMethod(nameof(CreditedSubjectsController.Delete))!.GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), false));
    }

    [Fact]
    public async Task CreditedUnits_MustBeBetweenZeroAndTheSubjectsUnits()
    {
        Task<CreditedSubjectDto> Make(decimal units) => _credits.CreateAsync(new CreateCreditedSubjectDto
            { UserId = _studentId, SubjectId = _s["IT 101"].SubjectID, SourceSchool = "Cebu Tech", CreditedUnits = units }, _registrarId);

        await Assert.ThrowsAsync<InvalidOperationException>(() => Make(0));
        var tooMany = await Assert.ThrowsAsync<InvalidOperationException>(() => Make(4));
        Assert.Contains("only 3 units", tooMany.Message);

        var partial = await Make(1.5m);
        Assert.Equal((1.5m, 3m, true), (partial.CreditedUnits, partial.Units, partial.IsPartial));
    }

    [Fact]
    public async Task PartialCredit_DoesNotSatisfyPrerequisitesOrPromotion()
    {
        await _credits.CreateAsync(new CreateCreditedSubjectDto
            { UserId = _studentId, SubjectId = _s["IT 101"].SubjectID, SourceSchool = "Cebu Tech", CreditedUnits = 2 }, _registrarId);

        var block = await _studyLoads.GetProposedBlockAsync(_studentId, _termId);
        var it102 = block.Single(b => b.SubjectCode == "IT 102");
        Assert.NotEmpty(it102.PrerequisiteMessages);
    }

    [Fact]
    public async Task CrossEnrollment_NeedsATerm_AndUsesItsSchoolYear()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() => _credits.CreateAsync(new CreateCreditedSubjectDto
            { UserId = _studentId, SubjectId = _s["GEC 101"].SubjectID, SourceSchool = "USC", CreditedUnits = 3, Kind = CreditKinds.CrossEnrollment }, _registrarId));

        var c = await _credits.CreateAsync(new CreateCreditedSubjectDto
        {
            UserId = _studentId, SubjectId = _s["GEC 101"].SubjectID, SourceSchool = "USC", CreditedUnits = 3,
            Kind = CreditKinds.CrossEnrollment, TermId = _termId, SchoolYear = "ignored"
        }, _registrarId);

        Assert.Equal((CreditKinds.CrossEnrollment, "2026-2027", "2026-2027 (2nd Sem)"), (c.Kind, c.SchoolYear, c.TermLabel));
        Assert.False(c.IsPartial);
    }
}
