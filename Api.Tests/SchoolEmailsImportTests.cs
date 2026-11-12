using System.Text;
using Api.Auth;
using Api.Domain.IdentityAccess;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

// The IT department's list of school emails: students who haven't signed in get theirs, so they can sign in.
public class SchoolEmailsImportTests : IDisposable
{
    private const string Domain = "dbtc-cebu.edu.ph";
    private readonly AppDbContext _context;
    private readonly Guid _ana = Guid.NewGuid();      // imported, no email yet
    private readonly Guid _ben = Guid.NewGuid();      // imported, email set by hand earlier
    private readonly Guid _cara = Guid.NewGuid();     // already signed in
    private readonly Guid _dan = Guid.NewGuid();      // imported, no email
    private readonly Guid _teacher = Guid.NewGuid();

    public SchoolEmailsImportTests()
    {
        _context = new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        Student(_ana, "25060208", "Ana", "Cruz", "", pending: true);
        Student(_ben, "25060209", "Ben", "Reyes", "ben.old@dbtc-cebu.edu.ph", pending: true);
        Student(_cara, "25060210", "Cara", "Lim", "cara.lim@dbtc-cebu.edu.ph", pending: false);
        Student(_dan, "25060211", "Dan Paul", "Uy", "", pending: true);
        _context.Users.Add(new User { UserID = _teacher, FirebaseUID = "fb-t", Email = "teacher@dbtc-cebu.edu.ph", Role = RoleUtils.Teacher, IsActive = true });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void Student(Guid id, string studentId, string first, string last, string email, bool pending)
    {
        _context.Users.Add(new User
        {
            UserID = id, Email = email, Role = RoleUtils.Student, IsActive = true,
            FirebaseUID = pending ? RecordsImportService.PendingUidPrefix + id.ToString("N") : "fb-" + id,
        });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = id, StudentID = studentId, Firstname = first, Lastname = last });
    }

    private Task<Api.DTOs.Enrollment.SchoolEmailsImportResultDto> Run(bool dryRun, params string[] lines) =>
        new SchoolEmailsImportService(_context).ImportAsync(
            new MemoryStream(Encoding.UTF8.GetBytes(string.Join("\n", lines))), "emails.csv", dryRun, Domain);

    private async Task<string> EmailOf(Guid id) => (await _context.Users.AsNoTracking().SingleAsync(u => u.UserID == id)).Email;

    [Fact]
    public async Task ById_SetsTheEmail_DryRunSavesNothing_AndImportingAgainChangesNothing()
    {
        var lines = new[] { "Student ID,Last Name,First Name,Email", "25060208,CRUZ,ANA,Ana.Cruz@dbtc-cebu.edu.ph", "25060209,REYES,BEN,ben.reyes@dbtc-cebu.edu.ph" };

        var dry = await Run(true, lines);
        Assert.Equal((2, 1), (dry.Emails, dry.Changed));
        Assert.Equal("ben.old@dbtc-cebu.edu.ph", dry.Rows.Single(r => r.StudentId == "25060209").OldEmail);
        Assert.Equal("", await EmailOf(_ana));

        var real = await Run(false, lines);
        Assert.Equal(2, real.Saved.Count);
        Assert.Equal("ana.cruz@dbtc-cebu.edu.ph", await EmailOf(_ana));   // lower case
        Assert.Equal("ben.reyes@dbtc-cebu.edu.ph", await EmailOf(_ben));

        var again = await Run(false, lines);
        Assert.Equal((0, 2), (again.Emails, again.AlreadySet));
    }

    [Fact]
    public async Task WithoutStudentId_MatchesByName_WithMiddleNameInTheFirstName()
    {
        var r = await Run(false, "Student Name,Email Address", "\"CRUZ, ANA MARIE SANTOS\",ana.cruz@dbtc-cebu.edu.ph", "\"UY, DAN PAUL\",dan.uy@dbtc-cebu.edu.ph",
            "\"CRUZ, ANABELLE\",anabelle@dbtc-cebu.edu.ph");

        Assert.Equal(2, r.Emails);
        Assert.All(r.Rows, row => Assert.Equal("name", row.MatchedBy));
        Assert.Equal("dan.uy@dbtc-cebu.edu.ph", await EmailOf(_dan));
        Assert.Equal(1, r.NotInSystem);   // "Anabelle" is not "Ana"
    }

    [Fact]
    public async Task SignedInStudents_UsedEmails_WrongDomain_AndUnknownIds_AreSkipped()
    {
        var r = await Run(false, "ID No.,Email",
            "25060210,cara.new@dbtc-cebu.edu.ph",     // signed in: not changed
            "25060208,teacher@dbtc-cebu.edu.ph",      // someone else's email
            "25060211,dan@gmail.com",                 // not a school email
            "99999999,x@dbtc-cebu.edu.ph",            // not in the system
            "12,y@dbtc-cebu.edu.ph",                  // not a valid ID
            "25060209,");                             // no email

        Assert.Equal(0, r.Emails);
        Assert.Equal(6, r.TotalProblems);
        Assert.Equal(1, r.NotInSystem);
        Assert.Contains(r.Problems, p => p.Message.Contains("already signed in"));
        Assert.Contains(r.Problems, p => p.Message.Contains("already belongs to another account"));
        Assert.Contains(r.Problems, p => p.Message.Contains("must end with @dbtc-cebu.edu.ph"));
        Assert.Equal("cara.lim@dbtc-cebu.edu.ph", await EmailOf(_cara));
    }

    [Fact]
    public async Task OneEmailForTwoStudents_SkipsBoth()
    {
        var r = await Run(false, "Student ID,Email", "25060208,same@dbtc-cebu.edu.ph", "25060211,same@dbtc-cebu.edu.ph");

        Assert.Equal(0, r.Emails);
        Assert.Contains(r.Problems, p => p.Message.Contains("given to two students"));
        Assert.Equal("", await EmailOf(_ana));
    }

    [Fact]
    public async Task AListWithoutTheColumns_IsAClearError()
    {
        var ex = await Assert.ThrowsAsync<InvalidDataException>(() => Run(true, "Name Only", "Ana"));
        Assert.Contains("Email column", ex.Message);
    }
}
