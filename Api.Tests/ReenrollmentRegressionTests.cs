using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.Enrollment;
using Api.DTOs.Reenrollment;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The three things that made online re-enrollment unusable on the live server, found on
/// 2026-11-28 by submitting as a real student against a database the API was connected to as
/// dbtc_api. All 1172 tests passed throughout, so each of these is a test that was missing.
///
/// <para>
/// Why the suite was blind. The portal's widget tests mock the repository, so nothing there
/// sends a real request. The service tests run on the InMemory provider, which has no row-level
/// security, and they call the service directly -- so model validation, which lives in the HTTP
/// pipeline, never runs. And their fixtures fill every field: ReenrollmentTests uses
/// Suffix = "N/A" and PreviousCollege = "N/A", while a real record holds '' for both.
/// </para>
/// </summary>
public class ReenrollmentRegressionTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public ReenrollmentRegressionTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b => b.UseEnvironment("Testing"));
    }

    // ── 1. The form the API hands the student has to be accepted back ────────
    //
    // The portal sends back exactly what it was given -- enrollment_view.dart does
    // `_form = Map.of(s.form)` and posts that -- so anything the GET can produce, the POST must
    // take. Suffix, MiddleName, PlaceOfBirth, SchoolAddress, PreviousCollege and PreviousCourse
    // are NOT NULL columns holding '' for a typical student, and plain [Required] rejects ''
    // as well as null. The student was told "The Suffix field is required." and could do nothing
    // about it: all six are in ReenrollmentService.LockedFields, so the UI will not let them be
    // edited, and the server overwrites them from the record anyway.

    /// <summary>Every locked field that is legitimately empty in a real record, one at a time.</summary>
    [Theory]
    [InlineData("suffix")]
    [InlineData("middleName")]
    [InlineData("placeOfBirth")]
    [InlineData("schoolAddress")]
    [InlineData("previousCollege")]
    [InlineData("previousCourse")]
    public async Task AnEmptyLockedField_ReachesTheService_InsteadOf400(string field)
    {
        var (client, service) = ClientWithMockedService();
        var body = PortalPayload();
        ((Dictionary<string, object?>)body["form"]!)[field] = "";

        var response = await client.PostAsJsonAsync("/api/me/reenrollment", body);

        Assert.True(response.StatusCode == HttpStatusCode.OK,
            $"an empty '{field}' was refused: {response.StatusCode} {await response.Content.ReadAsStringAsync()}");
        service.Verify(s => s.SubmitAsync(It.IsAny<Guid>(), It.IsAny<SubmitReenrollmentDto>(), It.IsAny<DateOnly>()), Times.Once);
    }

    /// <summary>All of them empty together, which is what a real record actually looks like.</summary>
    [Fact]
    public async Task TheFormOfAStudentWithNoSuffixAndNoPreviousCollege_IsAccepted()
    {
        var (client, service) = ClientWithMockedService();
        var body = PortalPayload();
        var form = (Dictionary<string, object?>)body["form"]!;
        foreach (var f in new[] { "suffix", "middleName", "placeOfBirth", "schoolAddress", "previousCollege", "previousCourse" })
        {
            form[f] = "";
        }

        var response = await client.PostAsJsonAsync("/api/me/reenrollment", body);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        service.Verify(s => s.SubmitAsync(It.IsAny<Guid>(), It.IsAny<SubmitReenrollmentDto>(), It.IsAny<DateOnly>()), Times.Once);
    }

    /// <summary>
    /// The loosening is deliberately not blanket. An empty first name, last name or sex is
    /// broken data for the Registrar to repair, not something to wave through, so those three
    /// stay strict -- this is the test that stops the fix from being widened by accident.
    /// </summary>
    [Theory]
    [InlineData("firstName")]
    [InlineData("lastName")]
    [InlineData("sex")]
    public async Task AnEmptyFieldThatMustNotBeEmpty_IsStillRefused(string field)
    {
        var (client, service) = ClientWithMockedService();
        var body = PortalPayload();
        ((Dictionary<string, object?>)body["form"]!)[field] = "";

        var response = await client.PostAsJsonAsync("/api/me/reenrollment", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        service.Verify(s => s.SubmitAsync(It.IsAny<Guid>(), It.IsAny<SubmitReenrollmentDto>(), It.IsAny<DateOnly>()), Times.Never);
    }

    /// <summary>A missing key is still a refusal: AllowEmptyStrings permits '', never null.</summary>
    [Fact]
    public async Task AMissingLockedField_IsStillRefused()
    {
        var (client, _) = ClientWithMockedService();
        var body = PortalPayload();
        ((Dictionary<string, object?>)body["form"]!).Remove("suffix");

        var response = await client.PostAsJsonAsync("/api/me/reenrollment", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    /// <summary>
    /// A client that is already a signed-in student. RequireStudent reads HttpContext.Items,
    /// which FirebaseAuthMiddleware fills from a real token, so the test stands a middleware in
    /// its place and mocks the user lookup behind it. The auth filters run at order -4000/-3000
    /// and body validation at -2000 (see AuthFilterOrder), so without this the request is 401ed
    /// before it ever reaches the validation these tests are about.
    /// </summary>
    private (HttpClient Client, Mock<IReenrollmentService> Service) ClientWithMockedService()
    {
        var student = Guid.NewGuid();
        var service = new Mock<IReenrollmentService>();
        service.Setup(s => s.SubmitAsync(It.IsAny<Guid>(), It.IsAny<SubmitReenrollmentDto>(), It.IsAny<DateOnly>()))
            .ReturnsAsync((Guid.NewGuid(), "2026-2027 (2nd Sem)", new List<string>()));

        var users = new Mock<IUserRepository>();
        users.Setup(r => r.GetByIdAsync(student)).ReturnsAsync(new User
        {
            UserID = student, FirebaseUID = "fb-test", Email = "student@dbtc-cebu.edu.ph",
            Role = RoleUtils.Student, IsActive = true,
        });

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                services.AddScoped<IReenrollmentService>(_ => service.Object);
                services.AddScoped<IUserRepository>(_ => users.Object);
                services.AddSingleton<IStartupFilter>(new SignedInAsStudent(student));
            });
        }).CreateClient();
        return (client, service);
    }

    /// <summary>Stands in for FirebaseAuthMiddleware: marks every request as this student.</summary>
    private sealed class SignedInAsStudent : IStartupFilter
    {
        private readonly Guid _student;
        public SignedInAsStudent(Guid student) => _student = student;

        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
        {
            app.Use(async (context, following) =>
            {
                context.Items["user_id"] = _student;
                context.Items["role"] = RoleUtils.Student;
                context.Items["email"] = "student@dbtc-cebu.edu.ph";
                await following();
            });
            next(app);
        };
    }

    /// <summary>
    /// The body the Student Portal sends: the form as the status endpoint returned it, with the
    /// keys it uses. Written as a dictionary rather than the DTO on purpose -- going through the
    /// DTO would serialise defaults for anything missing and hide exactly what is being tested.
    /// </summary>
    private static Dictionary<string, object?> PortalPayload() => new()
    {
        ["termId"] = Guid.NewGuid(),
        ["yearLevel"] = 3,
        ["confirmed"] = true,
        ["contacts"] = new[]
        {
            new Dictionary<string, object?>
            {
                ["relationType"] = 2, ["firstName"] = "Maria", ["lastName"] = "Cruz", ["contactNo"] = "09170000002",
            },
        },
        ["form"] = new Dictionary<string, object?>
        {
            ["firstName"] = "Ana", ["middleName"] = "Santos", ["lastName"] = "Cruz", ["suffix"] = "",
            ["dateOfBirth"] = "2006-03-14", ["placeOfBirth"] = "Cebu City", ["sex"] = "Female",
            ["civilStatus"] = "Single", ["nationality"] = "Filipino", ["mobileNumber"] = "09171111111",
            ["barangay"] = "Pardo", ["cityMunicipality"] = "Cebu City", ["province"] = "Cebu",
            ["zipCode"] = "6000", ["lastSchoolAttended"] = "Abellana NHS", ["schoolAddress"] = "Cebu City",
            ["yearGraduated"] = "2025-03-01", ["previousCollege"] = "", ["previousCourse"] = "",
            ["yearLevel"] = 3,
        },
    };
}

/// <summary>
/// 2. A failed save must not be reported as a duplicate submission.
///
/// <para>
/// SubmitAsync caught every DbUpdateException and answered "You already sent your enrollment for
/// &lt;term&gt;." On the live server the real cause was a row-level security policy refusing the
/// insert, so nothing was saved -- the student reloaded, saw Ready again, submitted again, and got
/// the same message forever. It also hid the actual fault for a day: the only sign of it was a
/// 42501 buried in the API log.
/// </para>
/// </summary>
public class ReenrollmentSaveFailureTests : IDisposable
{
    private readonly ThrowingDbContext _context;
    private readonly ReenrollmentService _service;
    private readonly Guid _student = Guid.NewGuid();
    private readonly AcademicTerm _first = new() { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 1 };
    private readonly AcademicTerm _second = new()
    {
        TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 2,
        EnrollmentOpensOn = new DateOnly(2026, 11, 17), EnrollmentClosesOn = new DateOnly(2026, 11, 28),
    };
    private static readonly DateOnly Open = new(2026, 11, 20);

    public ReenrollmentSaveFailureTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ThrowingDbContext(options);
        _service = new ReenrollmentService(_context);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS Information Technology" });
        _context.AcademicTerms.AddRange(_first, _second);
        var subject = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT 101", SubjectTitle = "Intro", LecUnits = 3, ProgramID = 1, YearLevel = 1, DefaultSemester = 1 };
        _context.Subjects.Add(subject);
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = subject.SubjectID, TermID = _first.TermID, ClassName = "BSIT 1A" };
        _context.Classes.Add(cls);

        _context.Users.Add(new User { UserID = _student, FirebaseUID = "fb-s", Email = "ana@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _student, Firstname = "Ana", Lastname = "Cruz", ProgramID = 1, YearLevel = 1 });
        var response = new EnrollmentResponse { ResponseID = Guid.NewGuid(), Timestamp = DateTime.UtcNow.AddMonths(-5), EmailAddress = "ana@dbtc-cebu.edu.ph", IsProcessed = true };
        var app = new EnrollmentApplication
        {
            ApplicationID = Guid.NewGuid(), ResponseID = response.ResponseID, ProgramID = 1, TermID = _first.TermID,
            Status = EnrollmentApplicationStatus.Active, StudentUserID = _student, CreatedAt = DateTime.UtcNow.AddMonths(-5),
        };
        // '' for suffix and the previous-college pair, as a real record holds them.
        var form = new EnrollmentForm
        {
            EnrollmentID = Guid.NewGuid(), ApplicationID = app.ApplicationID,
            FirstName = "Ana", MiddleName = "", LastName = "Cruz", Suffix = "",
            DateOfBirth = new DateOnly(2006, 3, 14), PlaceOfBirth = "Cebu City", Sex = "Female", CivilStatus = "Single",
            Nationality = "Filipino", MobileNumber = "09171111111", Barangay = "Pardo", CityMunicipality = "Cebu City",
            Province = "Cebu", ZipCode = "6000", LastSchoolAttended = "Abellana NHS", SchoolAddress = "",
            YearGraduated = new DateOnly(2025, 3, 1), PreviousCollege = "", PreviousCourse = "", YearLevel = 1,
        };
        _context.EnrollmentResponses.Add(response);
        _context.EnrollmentApplications.Add(app);
        _context.EnrollmentForms.Add(form);
        _context.StudyLoads.Add(new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = _student, ClassID = cls.ClassID, LoadStatus = StudyLoadStatus.Enrolled, CreatedAt = DateTime.UtcNow });
        _context.GradeClearances.Add(new GradeClearance { ClearanceID = Guid.NewGuid(), UserID = _student, TermID = _first.TermID, IsCleared = true });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private async Task<SubmitReenrollmentDto> ReadyToSend()
    {
        var status = await _service.GetStatusAsync(_student, Open);
        Assert.Equal(ReenrollmentStates.Ready, status.State);
        return new SubmitReenrollmentDto
        {
            TermId = status.TermId!.Value, YearLevel = 1, Form = status.Form!, Contacts = status.Contacts, Confirmed = true,
        };
    }

    /// <summary>A policy refusal is not a duplicate, and must not claim the enrollment was sent.</summary>
    [Fact]
    public async Task WhenRowLevelSecurityRefusesTheInsert_TheStudentIsNotToldItWasSent()
    {
        var dto = await ReadyToSend();
        _context.FailWith = Postgres("42501", "new row violates row-level security policy for table \"EnrollmentResponses\"");

        var ex = await Assert.ThrowsAsync<DbUpdateException>(() => _service.SubmitAsync(_student, dto, Open));

        Assert.DoesNotContain("already sent", ex.Message);
        Assert.Equal(0, await _context.EnrollmentApplications.CountAsync(a => a.TermID == _second.TermID));
    }

    /// <summary>Nor is a missing grant, or any other fault we have not thought of.</summary>
    [Fact]
    public async Task WhenTheSaveFailsForSomeOtherReason_ItIsNotCalledADuplicate()
    {
        var dto = await ReadyToSend();
        _context.FailWith = Postgres("42501", "permission denied for table \"EnrollmentApplications\"");

        var ex = await Assert.ThrowsAsync<DbUpdateException>(() => _service.SubmitAsync(_student, dto, Open));

        Assert.DoesNotContain("already sent", ex.Message);
    }

    /// <summary>The one case that IS a duplicate still reads the way it did.</summary>
    [Fact]
    public async Task AUniqueViolation_IsStillReportedAsAlreadySent()
    {
        var dto = await ReadyToSend();
        _context.FailWith = Postgres("23505", "duplicate key value violates unique constraint \"idx_one_application_per_term\"");

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitAsync(_student, dto, Open));

        Assert.Contains("already sent", ex.Message);
    }

    private static DbUpdateException Postgres(string sqlState, string message) =>
        new("An error occurred while saving the entity changes.",
            new Npgsql.PostgresException(message, "ERROR", "ERROR", sqlState));

    /// <summary>An InMemory context whose save can be made to fail the way Postgres would.</summary>
    private sealed class ThrowingDbContext : TestAppDbContext
    {
        public ThrowingDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbUpdateException? FailWith { get; set; }

        public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            if (FailWith is { } boom)
            {
                FailWith = null; // one failure, so the assertions afterwards can still read
                throw boom;
            }
            return base.SaveChangesAsync(cancellationToken);
        }
    }
}

/// <summary>
/// 3. Every table the submission writes needs a policy for role 5.
///
/// <para>
/// This is a guard, not proof. Nothing in this suite can enforce row-level security: the other
/// tests use the InMemory provider, which has no policies, and the Postgres-backed ones connect
/// as the table OWNER, which Postgres exempts from them. So the check that can be made here is
/// that the policy scripts still cover every table SubmitAsync writes to -- which is what caught
/// nobody out on 2026-11-22, when four tables were written and none of them admitted a student.
/// If a fifth table ever joins that batch, this fails until rls_02 and rls_06 are updated.
/// </para>
/// </summary>
public class ReenrollmentPolicyCoverageTests
{
    /// <summary>The tables ReenrollmentService.SubmitAsync inserts into, in EF's order.</summary>
    private static readonly string[] Written =
    {
        "EnrollmentResponses", "EnrollmentApplications", "EnrollmentForms", "Contacts",
    };

    private static string ScriptsDirectory()
    {
        var dir = AppContext.BaseDirectory;
        while (dir != null && !Directory.Exists(Path.Combine(dir, "Api", "Migrations", "Scripts")))
        {
            dir = Directory.GetParent(dir)?.FullName;
        }
        Assert.NotNull(dir);
        return Path.Combine(dir!, "Api", "Migrations", "Scripts");
    }

    [Theory]
    [InlineData("rls_02_policies.sql")]
    [InlineData("rls_06_reenrollment.sql")]
    public void EveryTableTheSubmissionWritesTo_HasAStudentInsertPolicy(string script)
    {
        var sql = File.ReadAllText(Path.Combine(ScriptsDirectory(), script));

        foreach (var table in Written)
        {
            var policy = $"CREATE POLICY \"{table}_student_insert\" ON \"{table}\" FOR INSERT";
            Assert.True(sql.Contains(policy),
                $"{script} has no student INSERT policy for \"{table}\". ReenrollmentService.SubmitAsync "
                + "writes it, so a student's submission will be refused by Postgres wherever RLS is enforced.");
        }
    }

    /// <summary>
    /// The student's response row is written with IsProcessed = true on purpose, so the public
    /// applicant's policy shape cannot be copied across: that clause is what refused a student.
    /// </summary>
    [Fact]
    public void TheStudentResponsePolicy_DoesNotRequireAnUnprocessedRow()
    {
        var sql = File.ReadAllText(Path.Combine(ScriptsDirectory(), "rls_06_reenrollment.sql"));
        var start = sql.IndexOf("CREATE POLICY \"EnrollmentResponses_student_insert\"", StringComparison.Ordinal);
        Assert.True(start >= 0);
        var clause = sql[start..sql.IndexOf(';', start)];

        Assert.DoesNotContain("\"IsProcessed\" = false", clause);
    }

    /// <summary>A student may only ever add rows, never change or remove what they have sent.</summary>
    [Fact]
    public void TheStudentPolicies_AreInsertOnly()
    {
        var sql = File.ReadAllText(Path.Combine(ScriptsDirectory(), "rls_06_reenrollment.sql"));

        foreach (var table in Written)
        {
            var start = sql.IndexOf($"CREATE POLICY \"{table}_student_insert\"", StringComparison.Ordinal);
            Assert.True(start >= 0);
            var statement = sql[start..sql.IndexOf(';', start)];
            Assert.Contains("FOR INSERT", statement);
            Assert.DoesNotContain("FOR ALL", statement);
            Assert.DoesNotContain("USING", statement); // WITH CHECK only; USING would imply read/update
        }
    }
}
