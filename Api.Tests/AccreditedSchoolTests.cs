using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Credits;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

public class AccreditedSchoolTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly AccreditedSchoolService _schools;
    private readonly CreditedSubjectService _credits;
    private readonly ReportService _reports;
    private readonly Guid _registrar = Guid.NewGuid();
    private readonly Dictionary<string, Subject> _s = new();

    public AccreditedSchoolTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _schools = new AccreditedSchoolService(_context);
        _credits = new CreditedSubjectService(_context);
        _reports = new ReportService(_context);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.Users.Add(new User { UserID = _registrar, FirebaseUID = "fb-r", Email = "r@x.com", Role = RoleUtils.Registrar, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _registrar, Firstname = "Rita", Lastname = "Reg" });
        foreach (var (code, lec) in new[] { ("IT 101", 3m), ("GEC 101", 3m), ("GEC 102", 2m) })
        {
            var s = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code, LecUnits = lec, ProgramID = 1, YearLevel = 1, DefaultSemester = 1 };
            _context.Subjects.Add(s);
            _s[code] = s;
        }
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private Guid Student(string first, int? type = null)
    {
        var id = Guid.NewGuid();
        _context.Users.Add(new User { UserID = id, FirebaseUID = "fb" + id, Email = id + "@x.com", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = id, Firstname = first, Lastname = "S", ProgramID = 1, YearLevel = 2, StudentType = type });
        _context.SaveChanges();
        return id;
    }

    private void Credit(Guid student, string code, string school)
    {
        _context.CreditedSubjects.Add(new CreditedSubject { CreditedSubjectID = Guid.NewGuid(), UserID = student, SubjectID = _s[code].SubjectID, SourceSchool = school, CreditedUnits = _s[code].LecUnits, RecordedByUserID = _registrar });
        _context.SaveChanges();
    }

    [Fact]
    public async Task Names_AreTidied_AndDuplicatesIgnoringCaseAreRefused()
    {
        var usc = await _schools.CreateAsync(new SaveAccreditedSchoolDto { Name = "  University of  San Carlos ", Address = " Cebu City " });
        Assert.Equal(("University of San Carlos", "Cebu City"), (usc.Name, usc.Address));

        await Assert.ThrowsAsync<InvalidOperationException>(() => _schools.CreateAsync(new SaveAccreditedSchoolDto { Name = "university of san carlos" }));
        await Assert.ThrowsAsync<InvalidOperationException>(() => _schools.CreateAsync(new SaveAccreditedSchoolDto { Name = "   " }));
        var controller = new AccreditedSchoolsController(_schools);
        Assert.IsType<BadRequestObjectResult>(await controller.Create(new SaveAccreditedSchoolDto { Name = "UNIVERSITY OF SAN CARLOS" }));
        Assert.IsType<NotFoundObjectResult>(await controller.Delete(Guid.NewGuid()));
    }

    [Fact]
    public async Task CreditsTypedDifferently_UseTheListSpelling_AndUnlistedNamesAreOffered()
    {
        await _schools.CreateAsync(new SaveAccreditedSchoolDto { Name = "Cebu Normal University" });
        var ana = Student("Ana");

        var credit = await _credits.CreateAsync(new CreateCreditedSubjectDto { UserId = ana, SubjectId = _s["IT 101"].SubjectID, SourceSchool = "cebu  normal university", CreditedUnits = 3 }, _registrar);
        Assert.Equal("Cebu Normal University", credit.SourceSchool);

        Credit(ana, "GEC 101", "Old School A");
        Credit(Student("Ben"), "GEC 101", "old school a ");
        var unlisted = Assert.Single(await _schools.GetUnlistedAsync());
        Assert.Equal(("Old School A", 2), (unlisted.Name, unlisted.CreditCount));

        var listed = Assert.Single(await _schools.GetAllAsync());
        Assert.Equal(1, listed.CreditCount);
    }

    [Fact]
    public async Task Renaming_UpdatesCreditsThatUsedTheOldName_DeletingKeepsThem()
    {
        var school = await _schools.CreateAsync(new SaveAccreditedSchoolDto { Name = "CTU" });
        var ana = Student("Ana");
        Credit(ana, "IT 101", "ctu");
        Credit(ana, "GEC 101", "Other College");

        await _schools.UpdateAsync(school.SchoolId, new SaveAccreditedSchoolDto { Name = "Cebu Technological University" });

        var names = await _context.CreditedSubjects.OrderBy(c => c.SourceSchool).Select(c => c.SourceSchool).ToListAsync();
        Assert.Equal(new[] { "Cebu Technological University", "Other College" }, names);

        await _schools.DeleteAsync(school.SchoolId);
        Assert.Empty(await _schools.GetAllAsync());
        Assert.Equal(2, await _context.CreditedSubjects.CountAsync());
    }

    [Fact]
    public async Task TransfereeReport_ListsTransfereesAndStudentsWithCredits()
    {
        var ana = Student("Ana");                // has credits, not marked as transferee
        var ben = Student("Ben", type: 3);       // transferee, no credits yet
        Student("Cy", type: 1);                  // new student, no credits: not listed
        Credit(ana, "IT 101", "USC");
        Credit(ana, "GEC 102", "USC");
        Credit(ana, "GEC 101", "CTU");

        var rows = await _reports.GetTransfereesAsync();

        Assert.Equal(new[] { "Ana S", "Ben S" }, rows.Select(r => r.StudentName));
        var a = rows[0];
        Assert.Equal(new[] { "CTU", "USC" }, a.PreviousSchools);
        Assert.Equal((3, 8m), (a.CreditedSubjects, a.CreditedUnits));
        Assert.Equal(new[] { "GEC 101", "GEC 102", "IT 101" }, a.CreditedCodes);
        Assert.Empty(rows[1].PreviousSchools);
        Assert.Equal(0, rows[1].CreditedSubjects);
    }
}
