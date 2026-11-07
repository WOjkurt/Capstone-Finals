using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Api.Auth;
using Api.Common;
using Api.Domain.Audit;
using Api.Domain.IdentityAccess;
using Api.DTOs.Enrollment;
using Api.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace Api.Tests;

/// <summary>The real API with a test database, where a request header picks who is signed in.</summary>
public class SecurityApiFactory : WebApplicationFactory<Program>
{
    public static readonly Guid Admin = Guid.NewGuid(), Registrar = Guid.NewGuid(), CollegeHead = Guid.NewGuid(),
        ProgramHead = Guid.NewGuid(), Teacher = Guid.NewGuid(), OtherTeacher = Guid.NewGuid(),
        Student = Guid.NewGuid(), OtherStudent = Guid.NewGuid();
    public static readonly Guid OtherClass = Guid.NewGuid(), OtherStudentLoad = Guid.NewGuid();

    private readonly string _database = "Security_" + Guid.NewGuid();
    private static readonly InMemoryDatabaseRoot Root = new();
    public Dictionary<string, string?> Settings { get; } = new()
    {
        ["RateLimiting:GlobalPermitLimit"] = "100000",
        ["RateLimiting:SearchPermitLimit"] = "100000",
        ["RateLimiting:WebhookPermitLimit"] = "100000",
        ["RateLimiting:IpPermitLimit"] = "100000",
    };

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(Settings));
        builder.ConfigureTestServices(services =>
        {
            foreach (var d in services.Where(d => d.ServiceType == typeof(DbContextOptions<AppDbContext>) ||
                                                  d.ServiceType == typeof(IDbContextOptionsConfiguration<AppDbContext>)).ToList())
            {
                services.Remove(d);
            }
            var options = new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(_database, Root).Options;
            services.RemoveAll<AppDbContext>();
            services.AddScoped<AppDbContext>(_ => new TestAppDbContext(options));
            services.AddTransient<IStartupFilter, FakeSignIn>();
        });
    }

    public void Seed()
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        if (db.Users.Any()) return;
        void Add(Guid id, int role) => db.Users.Add(new User
        {
            UserID = id, FirebaseUID = id.ToString(), Email = $"{id}@dbtc-cebu.edu.ph", Role = role, CreatedAt = DateTime.UtcNow
        });
        Add(Admin, RoleUtils.Admin);
        Add(Registrar, RoleUtils.Registrar);
        Add(CollegeHead, RoleUtils.CollegeHead);
        Add(ProgramHead, RoleUtils.ProgramHead);
        Add(Teacher, RoleUtils.Teacher);
        Add(OtherTeacher, RoleUtils.Teacher);
        Add(Student, RoleUtils.Student);
        Add(OtherStudent, RoleUtils.Student);

        var term = Guid.NewGuid();
        var subject = Guid.NewGuid();
        db.AcademicTerms.Add(new() { TermID = term, SchoolYear = "2026-2027", Semester = 1, IsActive = true });
        db.Subjects.Add(new() { SubjectID = subject, SubjectCode = "IT 101", SubjectTitle = "Computing", ProgramID = 1 });
        db.Classes.Add(new() { ClassID = OtherClass, SubjectID = subject, TermID = term, ClassName = "BSIT 1A", UserID = OtherTeacher, CreatedAt = DateTime.UtcNow });
        db.StudyLoads.Add(new() { StudyLoadID = OtherStudentLoad, UserID = OtherStudent, ClassID = OtherClass });
        db.SaveChanges();
    }

    private sealed class FakeSignIn : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
        {
            app.Use(async (context, nextStep) =>
            {
                if (Guid.TryParse(context.Request.Headers["X-Test-User"], out var id))
                {
                    context.Items["user_id"] = id;
                    context.Items["role"] = int.Parse(context.Request.Headers["X-Test-Role"]!);
                    context.Items["email"] = $"{id}@dbtc-cebu.edu.ph";
                }
                await nextStep();
            });
            next(app);
        };
    }
}

/// <summary>Tries every endpoint as someone who should not get in, so a new endpoint is checked automatically.</summary>
public class SecurityAccessTests : IClassFixture<SecurityApiFactory>
{
    private const string Guid1 = "00000000-0000-0000-0000-000000000001";
    private readonly SecurityApiFactory _factory;
    private readonly HttpClient _client;

    public SecurityAccessTests(SecurityApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
        factory.Seed();
    }

    /// <summary>What any signed-in person may reach. Each still limits the data by who is asking.</summary>
    private static readonly HashSet<string> OpenToAnySignedInUser = new(StringComparer.OrdinalIgnoreCase)
    {
        "GET api/AcademicPrograms", "GET api/AcademicPrograms/{id:int}",
        "GET api/AcademicTerms", "GET api/AcademicTerms/active", "GET api/AcademicTerms/{id:guid}",
        "GET api/Subjects", "GET api/Subjects/{id:guid}", "GET api/Subjects/{id:guid}/prerequisites",
        "GET api/classes", "GET api/classes/{id:guid}", "GET api/classes/{classId:guid}/schedules",
        "GET api/grades/studyload/{studyLoadId:guid}", "GET api/grades/class/{classId:guid}", "GET api/grades/student/{userId:guid}",
        "GET api/gradeclearances/{userId:guid}",
        "POST api/gradecorrections", "GET api/gradecorrections/mine", "GET api/gradecorrections/{id:guid}",
        "GET api/studyloads/student/{userId:guid}", "GET api/studyloads/class/{classId:guid}",
        "GET api/UserDetails/me", "GET api/Me",
    };

    private List<(string Key, string Method, string Url)> AllEndpoints()
    {
        var found = new List<(string, string, string)>();
        foreach (var e in _factory.Services.GetRequiredService<EndpointDataSource>().Endpoints.OfType<RouteEndpoint>())
        {
            var pattern = e.RoutePattern.RawText!.TrimStart('/');
            var url = System.Text.RegularExpressions.Regex.Replace(pattern, @"\{[^}]*:guid\}", Guid1);
            url = System.Text.RegularExpressions.Regex.Replace(url, @"\{[^}]*:int\}", "1");
            foreach (var method in e.Metadata.GetMetadata<HttpMethodMetadata>()?.HttpMethods ?? [])
            {
                found.Add(($"{method} {pattern}", method, url));
            }
        }
        Assert.True(found.Count > 100, $"Expected every API endpoint, found {found.Count}.");
        return found;
    }

    private async Task<HttpResponseMessage> SendAsync(string method, string url, Guid? user = null, int role = 0, object? body = null)
    {
        var request = new HttpRequestMessage(new HttpMethod(method), url);
        if (method != "GET") request.Content = JsonContent.Create(body ?? new { });
        if (user.HasValue)
        {
            request.Headers.Add("X-Test-User", user.ToString());
            request.Headers.Add("X-Test-Role", role.ToString());
        }
        return await _client.SendAsync(request);
    }

    [Fact]
    public async Task EveryEndpoint_WithoutSignIn_Returns401()
    {
        var wrong = new List<string>();
        foreach (var (key, method, url) in AllEndpoints())
        {
            var response = await SendAsync(method, url);
            if (response.StatusCode != HttpStatusCode.Unauthorized) wrong.Add($"{key} -> {(int)response.StatusCode}");
        }
        Assert.Empty(wrong);
    }

    [Theory]
    [InlineData(RoleUtils.Student)]
    [InlineData(RoleUtils.Teacher)]
    public async Task StaffEndpoints_AsStudentOrTeacher_Return403(int role)
    {
        var user = role == RoleUtils.Student ? SecurityApiFactory.Student : SecurityApiFactory.Teacher;
        var teacherOnly = new[] { "POST api/grades/submit", "POST api/grades/submit-batch" };
        var wrong = new List<string>();
        foreach (var (key, method, url) in AllEndpoints())
        {
            if (OpenToAnySignedInUser.Contains(key) || key.Contains("EnrollmentResponses") && method == "POST") continue;
            if (role == RoleUtils.Teacher && teacherOnly.Contains(key)) continue;
            var response = await SendAsync(method, url, user, role);
            if (response.StatusCode != HttpStatusCode.Forbidden) wrong.Add($"{key} -> {(int)response.StatusCode}");
        }
        Assert.Empty(wrong);
    }

    [Theory]
    [InlineData(RoleUtils.Registrar)]
    [InlineData(RoleUtils.CollegeHead)]
    [InlineData(RoleUtils.ProgramHead)]
    public async Task StaffAccountManagement_IsAdminOnly(int role)
    {
        var user = role switch
        {
            RoleUtils.Registrar => SecurityApiFactory.Registrar,
            RoleUtils.CollegeHead => SecurityApiFactory.CollegeHead,
            _ => SecurityApiFactory.ProgramHead,
        };
        var staffRoutes = AllEndpoints().Where(e => e.Key.Contains("admin/staff", StringComparison.OrdinalIgnoreCase)).ToList();
        Assert.NotEmpty(staffRoutes);
        foreach (var (_, method, url) in staffRoutes)
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await SendAsync(method, url, user, role)).StatusCode);
        }
    }

    [Fact]
    public async Task AnAdminRoleInTheRequestBody_CannotBeSetByARegistrar()
    {
        var response = await SendAsync("POST", "api/admin/staff", SecurityApiFactory.Registrar, RoleUtils.Registrar,
            new { email = "x@dbtc-cebu.edu.ph", firstname = "A", lastname = "B", role = RoleUtils.Admin });
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData("api/grades/student/{0}")]
    [InlineData("api/studyloads/student/{0}")]
    [InlineData("api/gradeclearances/{0}")]
    public async Task Student_CannotReadAnotherStudentsRecords(string route)
    {
        var url = string.Format(route, SecurityApiFactory.OtherStudent);
        var response = await SendAsync("GET", url, SecurityApiFactory.Student, RoleUtils.Student);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Student_CannotReadAGradeFromAnotherStudentsLoad()
    {
        var response = await SendAsync("GET", $"api/grades/studyload/{SecurityApiFactory.OtherStudentLoad}",
            SecurityApiFactory.Student, RoleUtils.Student);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData("api/grades/class/{0}")]
    [InlineData("api/studyloads/class/{0}")]
    [InlineData("api/classes/{0}")]
    public async Task Teacher_CannotReadAnotherTeachersClass(string route)
    {
        var url = string.Format(route, SecurityApiFactory.OtherClass);
        var response = await SendAsync("GET", url, SecurityApiFactory.Teacher, RoleUtils.Teacher);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task InvalidBody_ReachesValidationOnlyForTheRightRole()
    {
        var body = new { email = "not-an-email", firstname = "", lastname = "Valid", role = 99 };
        var response = await SendAsync("POST", "api/admin/staff", SecurityApiFactory.Admin, RoleUtils.Admin, body);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.False(string.IsNullOrWhiteSpace(json.GetProperty("message").GetString()));
    }

    [Fact]
    public async Task GradeCorrection_ReasonOver500Characters_Returns400()
    {
        var body = new { gradeId = Guid1, correctionPeriod = 1, oldGrade = 2.0, newGrade = 1.5, reason = new string('x', 501) };
        var response = await SendAsync("POST", "api/gradecorrections", SecurityApiFactory.Teacher, RoleUtils.Teacher, body);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task RefusedRequest_IsRecordedOnceInTheActivityLog()
    {
        var url = $"api/grades/student/{SecurityApiFactory.OtherStudent}";
        await SendAsync("GET", url, SecurityApiFactory.Student, RoleUtils.Student);
        await SendAsync("GET", url, SecurityApiFactory.Student, RoleUtils.Student);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var logged = db.ActivityLogs.Where(l => l.Action == ActivityActions.AccessDenied && l.Summary.Contains(url)).ToList();
        Assert.Single(logged);
        Assert.Equal(SecurityApiFactory.Student, logged[0].ActorUserID);
    }
}

public class SecurityRateLimitTests
{
    [Fact]
    public async Task EachPersonHasTheirOwnLimit_OnTheSameAddress()
    {
        using var factory = new SecurityApiFactory();
        factory.Settings["RateLimiting:GlobalPermitLimit"] = "3";
        var client = factory.CreateClient();
        factory.Seed();

        async Task<HttpStatusCode> Call(Guid user)
        {
            var request = new HttpRequestMessage(HttpMethod.Get, "api/AcademicTerms");
            request.Headers.Add("X-Test-User", user.ToString());
            request.Headers.Add("X-Test-Role", RoleUtils.Student.ToString());
            request.Headers.Add("X-Forwarded-For", "192.0.2.50");
            return (await client.SendAsync(request)).StatusCode;
        }

        for (int i = 0; i < 3; i++) Assert.Equal(HttpStatusCode.OK, await Call(SecurityApiFactory.Student));
        Assert.Equal(HttpStatusCode.TooManyRequests, await Call(SecurityApiFactory.Student));
        Assert.Equal(HttpStatusCode.OK, await Call(SecurityApiFactory.OtherStudent));
    }
}

/// <summary>On PostgreSQL only: it stores the form as jsonb, which reorders the keys and is missing from the in-memory database.</summary>
public class DuplicateEnrollmentFormTests
{
    private static ServiceProvider Services()
    {
        var s = new ServiceCollection();
        s.AddLogging();
        s.AddDbContext<AppDbContext>(o => o.UseNpgsql(Environment.GetEnvironmentVariable("TEST_POSTGRES")));
        s.AddScoped<Api.Repositories.IEnrollmentResponseRepository, Api.Repositories.EnrollmentResponseRepository>();
        s.AddScoped<Api.Repositories.IEnrollmentApplicationRepository, Api.Repositories.EnrollmentApplicationRepository>();
        s.AddScoped<Api.Repositories.IEnrollmentFormRepository, Api.Repositories.EnrollmentFormRepository>();
        s.AddScoped<Api.Repositories.IContactRepository, Api.Repositories.ContactRepository>();
        s.AddScoped<Api.Repositories.IUserDetailsRepository, Api.Repositories.UserDetailsRepository>();
        s.AddScoped<Api.Repositories.IUserRepository, Api.Repositories.UserRepository>();
        s.AddScoped<IEnrollmentService, EnrollmentService>();
        return s.BuildServiceProvider();
    }

    private static async Task<(Guid First, Guid Second, int Rows)> SubmitTwice(string email, string secondName, string secondEmail)
    {
        await using var services = Services();
        async Task<Guid> Submit(string name, string address)
        {
            await using var scope = services.CreateAsyncScope();
            return await scope.ServiceProvider.GetRequiredService<IEnrollmentService>().CreateResponseAsync(new CreateEnrollmentResponseDto
            {
                EmailAddress = address,
                Form = new ResponseFormDataDto { FirstName = name, LastName = "Cruz", Barangay = "Punta Princesa" }
            });
        }

        var first = await Submit("Ana", email);
        var second = await Submit(secondName, secondEmail);
        await using var check = services.CreateAsyncScope();
        var rows = await check.ServiceProvider.GetRequiredService<AppDbContext>().EnrollmentResponses
            .CountAsync(r => r.EmailAddress.ToLower() == email.ToLower());
        return (first, second, rows);
    }

    [PostgresFact]
    public async Task TheSameFormTwice_IsStoredOnce()
    {
        var email = $"same{Guid.NewGuid():N}@example.com";
        var (first, second, rows) = await SubmitTwice(email, "Ana", email.ToUpper());
        Assert.Equal(first, second);
        Assert.Equal(1, rows);
    }

    [PostgresFact]
    public async Task ACorrectedForm_IsKept()
    {
        var email = $"fixed{Guid.NewGuid():N}@example.com";
        var (first, second, rows) = await SubmitTwice(email, "Anna", email);
        Assert.NotEqual(first, second);
        Assert.Equal(2, rows);
    }
}

public class PersonNameTests
{
    private static readonly PersonNameAttribute Rule = new();

    [Theory]
    [InlineData("Maria")]
    [InlineData("Peña")]
    [InlineData("NIÑO")]
    [InlineData("De la Cruz")]
    [InlineData("O'Brien")]
    [InlineData("Santos-Reyes")]
    [InlineData("Jr.")]
    [InlineData("N/A")]
    [InlineData("n/a")]
    [InlineData("")]
    [InlineData(null)]
    public void Accepts(string? name) => Assert.True(Rule.IsValid(name));

    [Theory]
    [InlineData("Мария")]
    [InlineData("玛丽亚")]
    [InlineData("José")]
    [InlineData("Maria2")]
    [InlineData("<script>")]
    [InlineData("Ana\nCruz")]
    [InlineData("Ana😀")]
    public void Refuses(string name) => Assert.False(Rule.IsValid(name));

    [Fact]
    public void Message_NamesTheField() =>
        Assert.StartsWith("First Name can only use", Rule.FormatErrorMessage("FirstName"));
}
