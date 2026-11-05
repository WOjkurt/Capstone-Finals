using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

public class ReportTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly ReportService _reports;
    private readonly Guid _term = Guid.NewGuid();
    private readonly Guid _otherTerm = Guid.NewGuid();
    private readonly Guid _teacher = Guid.NewGuid();
    private readonly Dictionary<string, Class> _classes = new();

    public ReportTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _reports = new ReportService(_context);

        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" },
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSME", ProgramName = "BS ME" });
        _context.AcademicTerms.AddRange(
            new AcademicTerm { TermID = _term, SchoolYear = "2026-2027", Semester = 1 },
            new AcademicTerm { TermID = _otherTerm, SchoolYear = "2026-2027", Semester = 2 });
        AddUser(_teacher, "Ben", "Teach", RoleUtils.Teacher, null, null);

        AddClass("IT 101 A", "IT 101", 1, 3, 0, _teacher, _term);
        AddClass("IT 102 A", "IT 102", 1, 2, 1, _teacher, _term);
        AddClass("ME 101 A", "ME 101", 2, 3, 0, null, _term);
        AddClass("IT 101 next", "IT 101X", 1, 3, 0, _teacher, _otherTerm);
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void AddUser(Guid id, string first, string last, int role, int? program, int? year)
    {
        _context.Users.Add(new User { UserID = id, FirebaseUID = "fb" + id, Email = id + "@x.com", Role = role, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = id, Firstname = first, Lastname = last, ProgramID = program, YearLevel = year, LRN = role == RoleUtils.Student ? "1234" : null });
    }

    private void AddClass(string name, string code, int program, decimal lec, decimal lab, Guid? teacher, Guid term)
    {
        var subject = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code + " title", LecUnits = lec, LabUnits = lab, ProgramID = program, YearLevel = 1, DefaultSemester = 1 };
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = subject.SubjectID, TermID = term, ClassName = name, UserID = teacher, CreatedAt = DateTime.UtcNow };
        _context.Subjects.Add(subject);
        _context.Classes.Add(cls);
        _classes[name] = cls;
    }

    private async Task<Guid> Student(string first, int program, int year)
    {
        var id = Guid.NewGuid();
        AddUser(id, first, "S", RoleUtils.Student, program, year);
        await _context.SaveChangesAsync();
        return id;
    }

    private async Task Load(Guid student, string cls, int status, int? remarks = null)
    {
        var load = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = student, ClassID = _classes[cls].ClassID, LoadStatus = status, CreatedAt = DateTime.UtcNow };
        _context.StudyLoads.Add(load);
        if (remarks.HasValue)
            _context.Grades.Add(new Grade { GradeID = Guid.NewGuid(), StudyLoadID = load.StudyLoadID, FinalGrade = remarks == 1 ? 2m : 5m, Remarks = remarks, SubmittedByUserID = _teacher });
        await _context.SaveChangesAsync();
    }

    [Fact]
    public async Task EnrollmentSummary_CountsStudentsOncePerProgramAndYear()
    {
        var ana = await Student("Ana", 1, 1);
        var ben = await Student("Ben", 1, 1);
        var cy = await Student("Cy", 1, 1);
        var dan = await Student("Dan", 2, 2);
        await Load(ana, "IT 101 A", StudyLoadStatus.Enrolled);
        await Load(ana, "IT 102 A", StudyLoadStatus.Pending);   // still counted once, as enrolled
        await Load(ben, "IT 101 A", StudyLoadStatus.Pending);   // pending only
        await Load(cy, "IT 101 A", StudyLoadStatus.Dropped);    // not counted
        await Load(dan, "ME 101 A", StudyLoadStatus.Enrolled);
        await Load(dan, "IT 101 next", StudyLoadStatus.Enrolled); // other term

        var rows = await _reports.GetEnrollmentSummaryAsync(_term);

        Assert.Equal(2, rows.Count);
        var it = rows.Single(r => r.ProgramCode == "BSIT");
        Assert.Equal((1, 1, 1), (it.YearLevel ?? 0, it.EnrolledStudents, it.PendingOnlyStudents));
        var me = rows.Single(r => r.ProgramCode == "BSME");
        Assert.Equal((2, 1, 0), (me.YearLevel ?? 0, me.EnrolledStudents, me.PendingOnlyStudents));
    }

    [Fact]
    public async Task ClassSizes_ListEveryClassOfTheTerm_WithTeacherAndCounts()
    {
        var ana = await Student("Ana", 1, 1);
        var ben = await Student("Ben", 1, 1);
        await Load(ana, "IT 101 A", StudyLoadStatus.Enrolled);
        await Load(ben, "IT 101 A", StudyLoadStatus.Pending);
        await Load(ben, "IT 102 A", StudyLoadStatus.Rejected);

        var rows = await _reports.GetClassSizesAsync(_term);

        Assert.Equal(new[] { "IT 101 A", "IT 102 A", "ME 101 A" }, rows.Select(r => r.ClassName));
        var it101 = rows[0];
        Assert.Equal(("Ben Teach", 1, 1), (it101.TeacherName, it101.Enrolled, it101.Pending));
        Assert.Equal((0, 0), (rows[1].Enrolled, rows[1].Pending));
        Assert.Null(rows[2].TeacherName);
    }

    [Fact]
    public async Task FailedStudents_OnlyFailedFinalGradesOnEnrolledLoadsOfTheTerm()
    {
        var ana = await Student("Ana", 1, 1);
        var ben = await Student("Ben", 1, 1);
        await Load(ana, "IT 101 A", StudyLoadStatus.Enrolled, remarks: 2);
        await Load(ana, "IT 102 A", StudyLoadStatus.Enrolled, remarks: 1);
        await Load(ben, "IT 101 A", StudyLoadStatus.Dropped, remarks: 2);
        await Load(ben, "IT 101 next", StudyLoadStatus.Enrolled, remarks: 2);

        var row = Assert.Single(await _reports.GetFailedStudentsAsync(_term));

        Assert.Equal("Ana S", row.StudentName);
        Assert.Equal("1234", row.Lrn);
        Assert.Equal("BSIT", row.ProgramCode);
        Assert.Equal("IT 101", row.SubjectCode);
        Assert.Equal(5m, row.FinalGrade);
        Assert.Equal("Ben Teach", row.TeacherName);
    }

    [Fact]
    public async Task TeacherLoads_GroupClassesByTeacher_UnassignedLast()
    {
        var ana = await Student("Ana", 1, 1);
        await Load(ana, "IT 101 A", StudyLoadStatus.Enrolled);
        await Load(ana, "IT 102 A", StudyLoadStatus.Pending); // pending not counted as a student

        var rows = await _reports.GetTeacherLoadsAsync(_term);

        Assert.Equal(2, rows.Count);
        Assert.Equal("Ben Teach", rows[0].TeacherName);
        Assert.Equal(2, rows[0].Classes);
        Assert.Equal(6m, rows[0].Units);
        Assert.Equal(1, rows[0].Students);
        Assert.Equal(new[] { "IT 101", "IT 102" }, rows[0].SubjectCodes);
        Assert.Equal("Unassigned", rows[1].TeacherName);
        Assert.Null(rows[1].TeacherUserId);
    }

    [Fact]
    public async Task UnknownTerm_IsNotFound_AndControllerIsRegistrarOnly()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _reports.GetClassSizesAsync(Guid.NewGuid()));

        var controller = new ReportsController(_reports);
        Assert.IsType<NotFoundObjectResult>(await controller.FailedStudents(Guid.NewGuid()));
        Assert.IsType<OkObjectResult>(await controller.TeacherLoads(_term));
        Assert.NotEmpty(typeof(ReportsController).GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), false));
    }

    [Fact]
    public async Task EnrollmentStatistics_CountsEnrolledStudentsByYearAndSex()
    {
        var ana = await Student("Ana", 1, 1);
        var ben = await Student("Ben", 1, 1);
        var cy = await Student("Cy", 1, 2);
        var dee = await Student("Dee", 1, 5);   // 5th year counts as 4th
        var eve = await Student("Eve", 1, 3);   // pending only: not counted
        var fay = await Student("Fay", 2, 1);   // no sex on record
        foreach (var s in new[] { ana, ben, cy, dee, fay }) await Load(s, s == fay ? "ME 101 A" : "IT 101 A", StudyLoadStatus.Enrolled);
        await Load(eve, "IT 101 A", StudyLoadStatus.Pending);
        await Load(ben, "IT 102 A", StudyLoadStatus.Enrolled);  // two subjects, still one student

        // Sex from the enrollment form, overridden by the Registrar's saved details.
        foreach (var (id, sex) in new[] { (ana, "Female"), (ben, "Male"), (cy, "Female"), (dee, "male") })
        {
            var response = new EnrollmentResponse { ResponseID = Guid.NewGuid(), EmailAddress = id + "@f.com", Timestamp = DateTime.UtcNow };
            var app = new EnrollmentApplication { ApplicationID = Guid.NewGuid(), ResponseID = response.ResponseID, ProgramID = 1, TermID = _term, StudentUserID = id, CreatedAt = DateTime.UtcNow };
            _context.EnrollmentResponses.Add(response);
            _context.EnrollmentApplications.Add(app);
            _context.EnrollmentForms.Add(new EnrollmentForm
            {
                EnrollmentID = Guid.NewGuid(), ApplicationID = app.ApplicationID, FirstName = "x", MiddleName = "", LastName = "y", Suffix = "",
                PlaceOfBirth = "Cebu", Sex = sex, CivilStatus = "Single", Nationality = "Filipino", MobileNumber = "0", Barangay = "b",
                CityMunicipality = "c", Province = "p", ZipCode = "6000", LastSchoolAttended = "s", SchoolAddress = "a", PreviousCollege = "N/A", PreviousCourse = "N/A", YearLevel = 1
            });
        }
        _context.StudentPersonalDetails.Add(new StudentPersonalDetails { UserID = cy, Sex = "Male", UpdatedByUserID = _teacher, UpdatedAt = DateTime.UtcNow });
        await _context.SaveChangesAsync();

        var rows = await _reports.GetEnrollmentStatisticsAsync(_term);

        Assert.Equal(new[] { "BSIT", "BSME" }, rows.Select(r => r.ProgramCode));
        var it = rows[0];
        Assert.Equal(new[] { 1, 1, 0, 1 }, it.Male);     // Ben (1st), Cy (2nd, overridden), Dee (5th -> 4th)
        Assert.Equal(new[] { 1, 0, 0, 0 }, it.Female);   // Ana
        Assert.Equal(0, it.SexNotRecorded);
        Assert.Equal(1, rows[1].SexNotRecorded);
        Assert.Equal(0, rows[1].Male.Sum() + rows[1].Female.Sum());
    }
}
