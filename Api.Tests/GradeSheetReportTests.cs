using Api.Auth;
using Api.Constants;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The grade sheet the Registrar files and prints: a class's marks as they stand, with who
/// checked them and whether the term's results are out.
///
/// What it counts matters more than what it lists. A sheet that says "2 with no final yet" when
/// one of those two dropped out in September would send somebody chasing a teacher for a mark
/// that is never coming.
/// </summary>
public class GradeSheetReportTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly ReportService _reports;

    private readonly Guid _termId = Guid.NewGuid();
    private readonly Guid _teacher = Guid.NewGuid();
    private readonly Guid _programHead = Guid.NewGuid();
    private Guid _classId, _emptyClassId;

    public GradeSheetReportTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase("Sheets_" + Guid.NewGuid()).Options;
        _context = new TestAppDbContext(options);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.AcademicTerms.Add(new AcademicTerm
        { TermID = _termId, SchoolYear = "2026-2027", Semester = 1, IsActive = true });

        void Staff(Guid id, int role, string first)
        {
            _context.Users.Add(new User { UserID = id, FirebaseUID = "fb" + id, Email = id + "@dbtc-cebu.edu.ph", Role = role, IsActive = true });
            _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = id, Firstname = first, Lastname = "Staff" });
        }
        Staff(_teacher, RoleUtils.Teacher, "Ben");
        Staff(_programHead, RoleUtils.ProgramHead, "Carla");

        _classId = SeedClass("IT 101");
        _emptyClassId = SeedClass("IT 102");
        _context.SaveChanges();

        _reports = new ReportService(_context);
    }

    private Guid SeedClass(string code)
    {
        var subject = new Subject
        { SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code + " title", LecUnits = 2, LabUnits = 1, ProgramID = 1, YearLevel = 1, DefaultSemester = 1 };
        var cls = new Class
        { ClassID = Guid.NewGuid(), SubjectID = subject.SubjectID, TermID = _termId, ClassName = code + " A", UserID = _teacher, CreatedAt = DateTime.UtcNow };
        _context.Subjects.Add(subject);
        _context.Classes.Add(cls);
        return cls.ClassID;
    }

    /// <summary>Puts a student in a class, optionally with marks and a load status.</summary>
    private Guid Enrol(Guid classId, string last, string first, string? studentId = null,
        decimal? midterm = null, decimal? final = null, int loadStatus = StudyLoadStatus.Enrolled,
        DateTime? modifiedAt = null)
    {
        var userId = Guid.NewGuid();
        _context.Users.Add(new User { UserID = userId, FirebaseUID = "fb" + userId, Email = userId + "@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails
        { UserDetailID = Guid.NewGuid(), UserID = userId, Firstname = first, Lastname = last, ProgramID = 1, StudentID = studentId });

        var load = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = userId, ClassID = classId, LoadStatus = loadStatus };
        _context.StudyLoads.Add(load);

        if (midterm != null || final != null)
        {
            _context.Grades.Add(new Grade
            {
                GradeID = Guid.NewGuid(), StudyLoadID = load.StudyLoadID,
                MidtermGrade = midterm, FinalGrade = final,
                Remarks = final == null ? null : (final > 3.0m ? 2 : 1),
                SubmittedByUserID = _teacher, DateSubmitted = DateTime.UtcNow,
                ModifiedAt = modifiedAt,
            });
        }
        _context.SaveChanges();
        return userId;
    }

    public void Dispose() => _context.Dispose();

    private Task<List<Api.DTOs.Reports.GradeSheetDto>> Sheets(Guid? classId = null) =>
        _reports.GetGradeSheetsAsync(_termId, classId);

    // ── What is on the sheet ────────────────────────────────────────────────

    [Fact]
    public async Task ASheetCarriesTheMarks_AndNamesTheClassAndTeacher()
    {
        Enrol(_classId, "Cruz", "Ana", studentId: "2026-0001", midterm: 2.0m, final: 2.25m);

        var sheet = Assert.Single(await Sheets(_classId));

        Assert.Equal("IT 101", sheet.SubjectCode);
        Assert.Equal("IT 101 A", sheet.ClassName);
        Assert.Equal("2026-2027 (1st Sem)", sheet.TermLabel);
        Assert.Equal("Ben Staff", sheet.TeacherName);
        Assert.Equal(3m, sheet.Units);   // lecture plus laboratory

        var row = Assert.Single(sheet.Students);
        Assert.Equal("Cruz, Ana", row.Name);
        Assert.Equal("2026-0001", row.StudentId);
        Assert.Equal(2.0m, row.MidtermGrade);
        Assert.Equal(2.25m, row.FinalGrade);
        Assert.Equal(1, row.Remarks);
    }

    [Fact]
    public async Task StudentsAreListedByName()
    {
        Enrol(_classId, "Santos", "Bea");
        Enrol(_classId, "Cruz", "Ana");
        Enrol(_classId, "delos Reyes", "Carlo");

        var sheet = Assert.Single(await Sheets(_classId));

        Assert.Equal(new[] { "Cruz, Ana", "delos Reyes, Carlo", "Santos, Bea" },
            sheet.Students.Select(r => r.Name));
    }

    [Fact]
    public async Task AMarkTheRegistrarChanged_IsShownAsChangedOnTheSheet()
    {
        var changed = DateTime.UtcNow.AddDays(-1);
        Enrol(_classId, "Cruz", "Ana", midterm: 2.0m, final: 1.75m, modifiedAt: changed);

        var row = Assert.Single((await Sheets(_classId)).Single().Students);

        Assert.NotNull(row.ModifiedAt);
    }

    // ── The counts, which are the point of it ───────────────────────────────

    [Fact]
    public async Task PassedFailedAndNotYetGraded_AreCountedSeparately()
    {
        Enrol(_classId, "A", "One", final: 1.5m);    // passed
        Enrol(_classId, "B", "Two", final: 3.0m);    // passed: 3.0 is the boundary
        Enrol(_classId, "C", "Three", final: 3.25m); // failed
        Enrol(_classId, "D", "Four", midterm: 2.0m); // no final yet

        var sheet = Assert.Single(await Sheets(_classId));

        Assert.Equal(2, sheet.Passed);
        Assert.Equal(1, sheet.Failed);
        Assert.Equal(1, sheet.NoFinalYet);
    }

    [Fact]
    public async Task AStudentWhoDroppedOrWithdrew_IsNotOnTheSheetAtAll()
    {
        Enrol(_classId, "Here", "Still", final: 2.0m);
        Enrol(_classId, "Gone", "Dropped", loadStatus: StudyLoadStatus.Dropped);
        Enrol(_classId, "Gone", "Withdrawn", loadStatus: StudyLoadStatus.Withdrawn);

        var sheet = Assert.Single(await Sheets(_classId));

        // Counting them would make every sheet look unfinished, and send somebody chasing a
        // teacher for a mark that is never coming.
        Assert.Equal("Here, Still", Assert.Single(sheet.Students).Name);
        Assert.Equal(0, sheet.NoFinalYet);
    }

    [Fact]
    public async Task AClassWithNobodyInIt_IsStillASheet()
    {
        var sheet = Assert.Single(await Sheets(_emptyClassId));

        Assert.Empty(sheet.Students);
        Assert.Equal(0, sheet.Passed);
        Assert.Equal(0, sheet.NoFinalYet);
    }

    // ── Who checked it, and whether it is out ───────────────────────────────

    [Fact]
    public async Task AnUncheckedSheetSaysSo()
    {
        var sheet = Assert.Single(await Sheets(_classId));

        Assert.Null(sheet.VerifiedAt);
        Assert.Null(sheet.VerifiedByName);
    }

    [Fact]
    public async Task AVerifiedSheetNamesWhoCheckedIt()
    {
        var cls = await _context.Classes.FirstAsync(c => c.ClassID == _classId);
        cls.VerifiedAt = DateTime.UtcNow;
        cls.VerifiedByUserID = _programHead;
        await _context.SaveChangesAsync();

        var sheet = Assert.Single(await Sheets(_classId));

        Assert.NotNull(sheet.VerifiedAt);
        Assert.Equal("Carla Staff", sheet.VerifiedByName);
    }

    [Fact]
    public async Task TheSheetSaysWhetherTheTermsResultsAreOut()
    {
        Assert.False((await Sheets(_classId)).Single().AreGradesReleased);

        var term = await _context.AcademicTerms.FirstAsync(t => t.TermID == _termId);
        term.GradesReleasedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        // A sheet can be finished and checked and still be withheld from students.
        Assert.True((await Sheets(_classId)).Single().AreGradesReleased);
    }

    // ── Asking for the whole term, or for one class ─────────────────────────

    [Fact]
    public async Task AskingForTheTermGivesEverySheetInIt_InSubjectOrder()
    {
        var sheets = await Sheets();

        Assert.Equal(new[] { "IT 101", "IT 102" }, sheets.Select(s => s.SubjectCode));
    }

    [Fact]
    public async Task AskingForAClassThatIsNotInThisTerm_IsNotFound()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(() => Sheets(Guid.NewGuid()));
    }

    [Fact]
    public async Task AskingForATermThatDoesNotExist_IsNotFound()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(
            () => _reports.GetGradeSheetsAsync(Guid.NewGuid(), null));
    }

    // ── Whether the caller may verify what they are looking at ──────────────

    [Fact]
    public async Task ASheetTheCallerEncoded_IsMarkedAsTheirOwnWork()
    {
        Enrol(_classId, "Cruz", "Ana", midterm: 2.0m, final: 2.25m);

        var sheets = await _reports.GetGradeSheetsAsync(_termId, null, _teacher);

        // Enrol submits every mark as the teacher, so IT 101 is theirs. IT 102 has nobody in
        // it, and an empty sheet is nobody's work -- there is nothing on it to have encoded.
        Assert.True(sheets.Single(sheet => sheet.ClassId == _classId).EncodedByCaller);
        Assert.False(sheets.Single(sheet => sheet.ClassId == _emptyClassId).EncodedByCaller);
    }

    [Fact]
    public async Task ASheetSomebodyElseEncoded_IsNotTheirOwnWork()
    {
        Enrol(_classId, "Cruz", "Ana", midterm: 2.0m, final: 2.25m);

        var sheets = await _reports.GetGradeSheetsAsync(_termId, null, _programHead);

        Assert.All(sheets, sheet => Assert.False(sheet.EncodedByCaller));
    }

    [Fact]
    public async Task CorrectingAMarkCountsAsHavingTouchedTheSheet()
    {
        Enrol(_classId, "Cruz", "Ana", midterm: 2.0m, final: 2.25m);
        var registrar = Guid.NewGuid();
        var grade = await _context.Grades.FirstAsync();
        grade.ModifiedByUserID = registrar;
        grade.ModifiedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        var sheets = await _reports.GetGradeSheetsAsync(_termId, null, registrar);

        // She did not type this mark, but she changed it, which is the same problem.
        Assert.True(sheets.Single(sheet => sheet.ClassId == _classId).EncodedByCaller);
    }

    [Fact]
    public async Task NobodyInParticularAsking_ClaimsNoSheetAsTheirs()
    {
        Enrol(_classId, "Cruz", "Ana", midterm: 2.0m, final: 2.25m);

        // The printed report has no caller, and must not light up every row as un-verifiable.
        Assert.All(await Sheets(), sheet => Assert.False(sheet.EncodedByCaller));
    }
}
