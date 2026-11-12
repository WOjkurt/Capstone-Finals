using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Records;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

// Students → Records check: what each active student still needs before their records are complete.
public class RecordsCheckTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly StudentRecordService _records;
    private readonly Guid _curriculum = Guid.NewGuid();
    private readonly Guid _complete = Guid.NewGuid();
    private readonly Guid _imported = Guid.NewGuid();   // pending, no email, no Student ID
    private readonly Guid _waiting = Guid.NewGuid();    // pending, email set
    private readonly Guid _noProgram = Guid.NewGuid();
    private readonly Guid _inactive = Guid.NewGuid();
    private readonly Guid _term = Guid.NewGuid();

    public RecordsCheckTests()
    {
        _context = new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        _records = new StudentRecordService(_context);
        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" },
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSME", ProgramName = "BS ME" });
        _context.Curricula.Add(new Curriculum { CurriculumID = _curriculum, ProgramID = 1, Name = "BSIT 2023", EffectiveFromYear = 2023 });
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _term, SchoolYear = "2025-2026", Semester = 1 });

        Student(_complete, "Ana", "Cruz", "ana@dbtc-cebu.edu.ph", "25060208", 1, 2, _curriculum, pending: false);
        _context.StudentPersonalDetails.Add(new StudentPersonalDetails
        {
            UserID = _complete, Address = "Cebu City", DateOfBirth = new DateOnly(2004, 1, 1), PlaceOfBirth = "Cebu",
            Sex = "Female", Nationality = "Filipino", EntranceData = "Cebu NHS", UpdatedAt = DateTime.UtcNow,
        });
        Student(_imported, "Ben", "Reyes", "", null, 1, 1, null, pending: true);
        Student(_waiting, "Cara", "Lim", "cara@dbtc-cebu.edu.ph", "25060210", 2, 1, null, pending: true);
        Student(_noProgram, "Dan", "Uy", "dan@dbtc-cebu.edu.ph", "25060211", null, null, null, pending: false);
        Student(_inactive, "Eve", "Tan", "", null, 1, 1, null, pending: true, active: false);

        // Cara's details come from her enrollment form, all but place of birth.
        var app = new EnrollmentApplication
        {
            ApplicationID = Guid.NewGuid(), ResponseID = Guid.NewGuid(), ProgramID = 2, TermID = _term,
            Status = EnrollmentApplicationStatus.Active, StudentUserID = _waiting, CreatedAt = DateTime.UtcNow,
        };
        _context.EnrollmentApplications.Add(app);
        _context.EnrollmentForms.Add(new EnrollmentForm
        {
            EnrollmentID = Guid.NewGuid(), ApplicationID = app.ApplicationID, FirstName = "Cara", MiddleName = "", LastName = "Lim", Suffix = "",
            DateOfBirth = new DateOnly(2005, 5, 5), PlaceOfBirth = "", Sex = "Female", CivilStatus = "Single", Nationality = "Filipino",
            MobileNumber = "", Barangay = "Lahug", CityMunicipality = "Cebu City", Province = "Cebu", ZipCode = "6000",
            LastSchoolAttended = "Cebu NHS", SchoolAddress = "", PreviousCollege = "", PreviousCourse = "",
        });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void Student(Guid id, string first, string last, string email, string? studentId, int? program, int? year, Guid? curriculum,
        bool pending, bool active = true)
    {
        _context.Users.Add(new User
        {
            UserID = id, Email = email, Role = RoleUtils.Student, IsActive = active,
            FirebaseUID = pending ? RecordsImportService.PendingUidPrefix + id.ToString("N") : "fb-" + id,
        });
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(), UserID = id, Firstname = first, Lastname = last, StudentID = studentId,
            ProgramID = program, YearLevel = year, CurriculumID = curriculum,
        });
    }

    [Fact]
    public async Task ListsOnlyActiveStudentsWithSomethingMissing_SortedByName()
    {
        var r = await _records.GetRecordsCheckAsync(null);

        Assert.Equal(4, r.ActiveStudents);
        Assert.Equal(new[] { "Lim", "Reyes", "Uy" }, r.Rows.Select(x => x.Lastname));   // Cruz is complete; Tan is inactive

        var ben = r.Rows.Single(x => x.UserId == _imported);
        Assert.Equal(new[] { RecordsCheckIssues.NoEmail, RecordsCheckIssues.NoStudentId, RecordsCheckIssues.NoCurriculum, RecordsCheckIssues.Transcript }, ben.Issues);
        Assert.False(ben.HasSignedIn);
        Assert.Equal(6, ben.Missing.Count);

        var cara = r.Rows.Single(x => x.UserId == _waiting);
        Assert.Contains(RecordsCheckIssues.NotSignedIn, cara.Issues);
        Assert.Equal(new[] { "Place of birth" }, cara.Missing);   // the rest comes from her form

        var dan = r.Rows.Single(x => x.UserId == _noProgram);
        Assert.Contains(RecordsCheckIssues.NoProgram, dan.Issues);
        Assert.Contains(RecordsCheckIssues.NoYearLevel, dan.Issues);
        Assert.DoesNotContain(RecordsCheckIssues.NoCurriculum, dan.Issues);   // no program: curriculum isn't asked yet

        Assert.Equal(1, r.Counts.Single(c => c.Key == RecordsCheckIssues.NoEmail).Count);
        Assert.Equal(3, r.Counts.Single(c => c.Key == RecordsCheckIssues.Transcript).Count);
    }

    [Fact]
    public async Task ProgramFilter_ShowsOnlyThatProgram()
    {
        var r = await _records.GetRecordsCheckAsync(2);
        Assert.Equal(1, r.ActiveStudents);
        Assert.Equal(_waiting, Assert.Single(r.Rows).UserId);
    }

    [Fact]
    public async Task MissingFields_MatchTheDetailsTab()
    {
        var r = await _records.GetRecordsCheckAsync(null);
        foreach (var row in r.Rows)
        {
            var d = await _records.GetPersonalDetailsAsync(row.UserId);
            var expected = new List<string>();
            if (d.Address == null) expected.Add("Address");
            if (d.DateOfBirth == null) expected.Add("Date of birth");
            if (d.PlaceOfBirth == null) expected.Add("Place of birth");
            if (d.Sex == null) expected.Add("Sex");
            if (d.Nationality == null) expected.Add("Nationality");
            if (d.EntranceData == null) expected.Add("Entrance data");
            Assert.Equal(expected, row.Missing);
        }
    }
}
