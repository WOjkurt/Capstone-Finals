using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Api.Auth;
using Api.Common;
using Api.Controllers;
using Api.Data;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Api.Services;
using FirebaseAdmin.Auth;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

public class SchoolEmailTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly EnrollmentApplicationRepository _appRepo;
    private readonly EnrollmentFormRepository _formRepo;
    private readonly EnrollmentResponseRepository _responseRepo;
    private readonly ContactRepository _contactRepo;
    private readonly UserDetailsRepository _userDetailsRepo;
    private readonly UserRepository _userRepo;
    private readonly EnrollmentService _enrollmentService;
    private readonly EnrollmentApplicationsController _controller;
    private readonly Guid _callerUserId = Guid.NewGuid();

    public SchoolEmailTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: "SchoolEmailTests_" + Guid.NewGuid())
            .Options;

        _context = new TestAppDbContext(options);
        _appRepo = new EnrollmentApplicationRepository(_context);
        _formRepo = new EnrollmentFormRepository(_context);
        _responseRepo = new EnrollmentResponseRepository(_context);
        _contactRepo = new ContactRepository(_context);
        _userDetailsRepo = new UserDetailsRepository(_context);
        _userRepo = new UserRepository(_context);

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                { "Auth:AllowedEmailDomain", "dbtc-cebu.edu.ph" }
            })
            .Build();

        _enrollmentService = new EnrollmentService(
            _context,
            _responseRepo,
            _appRepo,
            _formRepo,
            _contactRepo,
            _userDetailsRepo,
            _userRepo,
            NullLogger<EnrollmentService>.Instance,
            config);

        _controller = new EnrollmentApplicationsController(_enrollmentService);
        var httpContext = new DefaultHttpContext();
        httpContext.Items["user_id"] = _callerUserId;
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = httpContext
        };
    }

    public void Dispose()
    {
        _context.Dispose();
    }

    private async Task<EnrollmentApplication> CreateApplicationAsync(
        int status = EnrollmentApplicationStatus.Approved,
        Guid? studentUserId = null,
        string? schoolEmail = null)
    {
        var term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 1, IsActive = true };
        _context.AcademicTerms.Add(term);

        var program = await _context.AcademicPrograms.FindAsync(1);
        if (program == null)
        {
            _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "Information Technology" });
        }
        await _context.SaveChangesAsync();

        var respId = Guid.NewGuid();
        var resp = new EnrollmentResponse
        {
            ResponseID = respId,
            EmailAddress = "applicant.personal@example.com",
            IsProcessed = true,
            Timestamp = DateTime.UtcNow,
            Data = JsonDocument.Parse("{}")
        };
        await _responseRepo.AddAsync(resp);

        var appId = Guid.NewGuid();
        var form = new EnrollmentForm
        {
            EnrollmentID = Guid.NewGuid(),
            ApplicationID = appId,
            FirstName = "Juan",
            MiddleName = "M",
            LastName = "Dela Cruz",
            Suffix = "",
            PlaceOfBirth = "Cebu",
            Sex = "Male",
            CivilStatus = "Single",
            Nationality = "Filipino",
            MobileNumber = "09123456789",
            Barangay = "Poblacion",
            CityMunicipality = "Cebu City",
            Province = "Cebu",
            ZipCode = "6000",
            LastSchoolAttended = "DBTC",
            SchoolAddress = "Punta Princesa",
            PreviousCollege = "N/A",
            PreviousCourse = "N/A",
            YearLevel = 1
        };
        await _formRepo.AddAsync(form);

        var app = new EnrollmentApplication
        {
            ApplicationID = appId,
            ResponseID = respId,
            ProgramID = 1,
            TermID = term.TermID,
            Status = status,
            StudentUserID = studentUserId,
            SchoolEmail = schoolEmail,
            CreatedAt = DateTime.UtcNow
        };
        await _appRepo.AddAsync(app);
        return app;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Endpoint Tests: PATCH /api/enrollment-applications/{id}/school-email
    // ─────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task UpdateSchoolEmail_SetValidEmail_Returns200AndUpdatedDto()
    {
        var app = await CreateApplicationAsync();
        var dto = new UpdateSchoolEmailDto { SchoolEmail = "student.juan@dbtc-cebu.edu.ph" };

        var result = await _controller.UpdateSchoolEmail(app.ApplicationID, dto);

        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(StatusCodes.Status200OK, okResult.StatusCode);
        var responseDto = Assert.IsType<EnrollmentApplicationResponseDto>(okResult.Value);
        Assert.Equal("student.juan@dbtc-cebu.edu.ph", responseDto.SchoolEmail);

        var saved = await _appRepo.GetByIdAsync(app.ApplicationID);
        Assert.NotNull(saved);
        Assert.Equal("student.juan@dbtc-cebu.edu.ph", saved.SchoolEmail);
    }

    [Fact]
    public async Task UpdateSchoolEmail_TrimAndLowercase_StoresCleanLowercase()
    {
        var app = await CreateApplicationAsync();
        var dto = new UpdateSchoolEmailDto { SchoolEmail = "   STUDENT.JUAN@DBTC-CEBU.EDU.PH   " };

        var result = await _controller.UpdateSchoolEmail(app.ApplicationID, dto);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var responseDto = Assert.IsType<EnrollmentApplicationResponseDto>(okResult.Value);
        Assert.Equal("student.juan@dbtc-cebu.edu.ph", responseDto.SchoolEmail);

        var saved = await _appRepo.GetByIdAsync(app.ApplicationID);
        Assert.NotNull(saved);
        Assert.Equal("student.juan@dbtc-cebu.edu.ph", saved.SchoolEmail);
    }

    [Fact]
    public async Task UpdateSchoolEmail_ClearValue_SetsNull()
    {
        var app = await CreateApplicationAsync(schoolEmail: "student.juan@dbtc-cebu.edu.ph");
        var dto = new UpdateSchoolEmailDto { SchoolEmail = null };

        var result = await _controller.UpdateSchoolEmail(app.ApplicationID, dto);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var responseDto = Assert.IsType<EnrollmentApplicationResponseDto>(okResult.Value);
        Assert.Null(responseDto.SchoolEmail);

        var saved = await _appRepo.GetByIdAsync(app.ApplicationID);
        Assert.NotNull(saved);
        Assert.Null(saved.SchoolEmail);

        // Also test empty / whitespace string clears value
        saved.SchoolEmail = "student.juan@dbtc-cebu.edu.ph";
        await _appRepo.UpdateAsync(saved);

        var whitespaceResult = await _controller.UpdateSchoolEmail(app.ApplicationID, new UpdateSchoolEmailDto { SchoolEmail = "   " });
        var whitespaceOk = Assert.IsType<OkObjectResult>(whitespaceResult);
        var whitespaceDto = Assert.IsType<EnrollmentApplicationResponseDto>(whitespaceOk.Value);
        Assert.Null(whitespaceDto.SchoolEmail);
    }

    [Fact]
    public async Task UpdateSchoolEmail_WrongDomain_Returns400BadRequest()
    {
        var app = await CreateApplicationAsync();
        var dto = new UpdateSchoolEmailDto { SchoolEmail = "student@gmail.com" };

        var result = await _controller.UpdateSchoolEmail(app.ApplicationID, dto);

        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(StatusCodes.Status400BadRequest, badRequest.StatusCode);
    }

    [Theory]
    [InlineData("attacker@evil-dbtc-cebu.edu.ph")]
    [InlineData("attacker@sub.dbtc-cebu.edu.ph")]
    [InlineData("attacker@dbtc-cebu.edu.ph.fake")]
    [InlineData("attacker@dbtc-cebu.edu.ph.evil.com")]
    public async Task UpdateSchoolEmail_LookalikeDomains_RejectedWith400BadRequest(string badEmail)
    {
        var app = await CreateApplicationAsync();
        var dto = new UpdateSchoolEmailDto { SchoolEmail = badEmail };

        var result = await _controller.UpdateSchoolEmail(app.ApplicationID, dto);

        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(StatusCodes.Status400BadRequest, badRequest.StatusCode);
    }

    [Theory]
    [InlineData("notanemail")]
    [InlineData("@dbtc-cebu.edu.ph")]
    [InlineData("student@@dbtc-cebu.edu.ph")]
    [InlineData("student with spaces@dbtc-cebu.edu.ph")]
    [InlineData("student@dbtc-cebu.edu.ph@extra")]
    public async Task UpdateSchoolEmail_InvalidFormat_Returns400BadRequest(string invalidEmail)
    {
        var app = await CreateApplicationAsync();
        var dto = new UpdateSchoolEmailDto { SchoolEmail = invalidEmail };

        var result = await _controller.UpdateSchoolEmail(app.ApplicationID, dto);

        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(StatusCodes.Status400BadRequest, badRequest.StatusCode);
    }

    [Fact]
    public async Task UpdateSchoolEmail_DuplicateSchoolEmail_Returns409Conflict()
    {
        var email = "duplicate.student@dbtc-cebu.edu.ph";
        await CreateApplicationAsync(schoolEmail: email);
        var app2 = await CreateApplicationAsync();

        var dto = new UpdateSchoolEmailDto { SchoolEmail = email.ToUpperInvariant() };

        var result = await _controller.UpdateSchoolEmail(app2.ApplicationID, dto);

        var conflict = Assert.IsType<ConflictObjectResult>(result);
        Assert.Equal(StatusCodes.Status409Conflict, conflict.StatusCode);
        Assert.Contains(email, conflict.Value?.ToString() ?? "");
    }

    [Fact]
    public async Task UpdateSchoolEmail_LinkedApplication_Returns400BadRequest()
    {
        var linkedUserId = Guid.NewGuid();
        var app = await CreateApplicationAsync(studentUserId: linkedUserId);
        var dto = new UpdateSchoolEmailDto { SchoolEmail = "student@dbtc-cebu.edu.ph" };

        var result = await _controller.UpdateSchoolEmail(app.ApplicationID, dto);

        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(StatusCodes.Status400BadRequest, badRequest.StatusCode);
        Assert.Contains("already been linked", badRequest.Value?.ToString() ?? "");
    }

    [Fact]
    public async Task UpdateSchoolEmail_StatusNotPendingOrApproved_Returns400BadRequest()
    {
        // Status 3 = Rejected, 4 = Active
        var app = await CreateApplicationAsync(status: 3);
        var dto = new UpdateSchoolEmailDto { SchoolEmail = "student@dbtc-cebu.edu.ph" };

        var result = await _controller.UpdateSchoolEmail(app.ApplicationID, dto);

        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(StatusCodes.Status400BadRequest, badRequest.StatusCode);
    }

    [Fact]
    public async Task UpdateSchoolEmail_UnknownApplicationId_Returns404NotFound()
    {
        var unknownId = Guid.NewGuid();
        var dto = new UpdateSchoolEmailDto { SchoolEmail = "student@dbtc-cebu.edu.ph" };

        var result = await _controller.UpdateSchoolEmail(unknownId, dto);

        var notFound = Assert.IsType<NotFoundObjectResult>(result);
        Assert.Equal(StatusCodes.Status404NotFound, notFound.StatusCode);
    }

    [Fact]
    public void UpdateSchoolEmail_ActionAndController_HaveRequireRegistrarOrAdminAttribute()
    {
        // Controller level
        var controllerAttr = typeof(EnrollmentApplicationsController)
            .GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), true);
        Assert.NotEmpty(controllerAttr);

        // Action level
        var method = typeof(EnrollmentApplicationsController).GetMethod(nameof(EnrollmentApplicationsController.UpdateSchoolEmail));
        Assert.NotNull(method);
        var actionAttr = method.GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), true);
        Assert.NotEmpty(actionAttr);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Middleware Tests
    // ─────────────────────────────────────────────────────────────────────────

    private static void ReplaceDbWithInMemory(IServiceCollection services, string dbName)
    {
        var descriptor = services.SingleOrDefault(
            d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
        if (descriptor != null) services.Remove(descriptor);
        var dbDescriptor = services.SingleOrDefault(d => d.ServiceType == typeof(AppDbContext));
        if (dbDescriptor != null) services.Remove(dbDescriptor);

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(dbName)
            .Options;

        services.AddScoped<AppDbContext>(_ => new TestAppDbContext(options));
    }

    private static WebApplicationFactory<Program> CreateMiddlewareFactory(
        string dbName,
        Mock<IFirebaseAuthVerifier> verifierMock)
    {
        return new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Testing");
            builder.ConfigureAppConfiguration((_, config) =>
            {
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    { "Auth:AllowedEmailDomain", "dbtc-cebu.edu.ph" },
                    { "Auth:RequireVerifiedEmail", "true" }
                });
            });
            builder.ConfigureTestServices(services =>
            {
                ReplaceDbWithInMemory(services, dbName);
                services.AddSingleton(verifierMock.Object);
            });
        });
    }

    private static FirebaseToken CreateFakeFirebaseToken(
        string uid,
        string email,
        bool? emailVerified = true)
    {
        var argsType = typeof(FirebaseToken).GetNestedType("Args", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic)!;
        var args = Activator.CreateInstance(argsType, true)!;
        argsType.GetProperty("Subject", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)!
            .SetValue(args, uid);

        var claims = new Dictionary<string, object>
        {
            { "email", email }
        };
        if (emailVerified.HasValue)
        {
            claims["email_verified"] = emailVerified.Value;
        }

        argsType.GetProperty("Claims", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)!
            .SetValue(args, claims);

        var ctor = typeof(FirebaseToken).GetConstructor(
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance,
            null,
            new[] { argsType },
            null)!;
        return (FirebaseToken)ctor.Invoke(new[] { args });
    }

    [Fact]
    public async Task Middleware_FirstLogin_SchoolEmailMatchesCaseInsensitive_CreatesUsersRow()
    {
        var testUid = "firstlogin-uid-" + Guid.NewGuid();
        var schoolEmail = "student.first@dbtc-cebu.edu.ph";
        var tokenEmail = "STUDENT.FIRST@DBTC-CEBU.EDU.PH"; // uppercase in token

        var mock = new Mock<IFirebaseAuthVerifier>();
        mock.Setup(v => v.IsInitialized).Returns(true);
        mock.Setup(v => v.VerifyIdTokenAsync("token-firstlogin-case", true))
            .ReturnsAsync(CreateFakeFirebaseToken(testUid, tokenEmail, emailVerified: true));

        var dbName = "FirstLoginCaseDb_" + Guid.NewGuid();
        using var factory = CreateMiddlewareFactory(dbName, mock);
        var client = factory.CreateClient();

        var options = new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(dbName).Options;
        using (var db = new TestAppDbContext(options))
        {
            var respId = Guid.NewGuid();
            db.EnrollmentResponses.Add(new EnrollmentResponse
            {
                ResponseID = respId,
                EmailAddress = "personal@gmail.com",
                IsProcessed = true,
                Timestamp = DateTime.UtcNow,
                Data = JsonDocument.Parse("{}")
            });
            db.EnrollmentApplications.Add(new EnrollmentApplication
            {
                ApplicationID = Guid.NewGuid(),
                ResponseID = respId,
                SchoolEmail = schoolEmail,
                Status = 2, // Approved
                StudentUserID = null,
                CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/Me")
        {
            Headers = { Authorization = new AuthenticationHeaderValue("Bearer", "token-firstlogin-case") }
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using (var db = new TestAppDbContext(options))
        {
            var user = await db.Users.FirstOrDefaultAsync(u => u.FirebaseUID == testUid);
            Assert.NotNull(user);
            Assert.Equal("student.first@dbtc-cebu.edu.ph", user.Email);
            Assert.Equal(RoleUtils.Student, user.Role);
        }
    }

    [Fact]
    public async Task Middleware_PersonalEmailInResponse_DoesNotGrantAccess_Returns401()
    {
        var testUid = "personal-only-uid-" + Guid.NewGuid();
        var tokenEmail = "applicant.personal@dbtc-cebu.edu.ph";

        var mock = new Mock<IFirebaseAuthVerifier>();
        mock.Setup(v => v.IsInitialized).Returns(true);
        mock.Setup(v => v.VerifyIdTokenAsync("token-personal-only", true))
            .ReturnsAsync(CreateFakeFirebaseToken(testUid, tokenEmail, emailVerified: true));

        var dbName = "PersonalOnlyDb_" + Guid.NewGuid();
        using var factory = CreateMiddlewareFactory(dbName, mock);
        var client = factory.CreateClient();

        var options = new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(dbName).Options;
        using (var db = new TestAppDbContext(options))
        {
            var respId = Guid.NewGuid();
            // EnrollmentResponse has token email as EmailAddress, but EnrollmentApplication has NO SchoolEmail
            db.EnrollmentResponses.Add(new EnrollmentResponse
            {
                ResponseID = respId,
                EmailAddress = tokenEmail,
                IsProcessed = true,
                Timestamp = DateTime.UtcNow,
                Data = JsonDocument.Parse("{}")
            });
            db.EnrollmentApplications.Add(new EnrollmentApplication
            {
                ApplicationID = Guid.NewGuid(),
                ResponseID = respId,
                SchoolEmail = null, // No school email set!
                Status = 2, // Approved
                StudentUserID = null,
                CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/Me")
        {
            Headers = { Authorization = new AuthenticationHeaderValue("Bearer", "token-personal-only") }
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("Registrar must register your school email", body);

        // Verify NO Users row was created
        using (var db = new TestAppDbContext(options))
        {
            var user = await db.Users.FirstOrDefaultAsync(u => u.FirebaseUID == testUid);
            Assert.Null(user);
        }
    }

    [Fact]
    public async Task Middleware_ApplicationNotApproved_Returns401()
    {
        var testUid = "not-approved-uid-" + Guid.NewGuid();
        var tokenEmail = "pending.student@dbtc-cebu.edu.ph";

        var mock = new Mock<IFirebaseAuthVerifier>();
        mock.Setup(v => v.IsInitialized).Returns(true);
        mock.Setup(v => v.VerifyIdTokenAsync("token-not-approved", true))
            .ReturnsAsync(CreateFakeFirebaseToken(testUid, tokenEmail, emailVerified: true));

        var dbName = "NotApprovedDb_" + Guid.NewGuid();
        using var factory = CreateMiddlewareFactory(dbName, mock);
        var client = factory.CreateClient();

        var options = new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(dbName).Options;
        using (var db = new TestAppDbContext(options))
        {
            var respId = Guid.NewGuid();
            db.EnrollmentResponses.Add(new EnrollmentResponse
            {
                ResponseID = respId,
                EmailAddress = "personal@gmail.com",
                IsProcessed = true,
                Timestamp = DateTime.UtcNow,
                Data = JsonDocument.Parse("{}")
            });
            db.EnrollmentApplications.Add(new EnrollmentApplication
            {
                ApplicationID = Guid.NewGuid(),
                ResponseID = respId,
                SchoolEmail = tokenEmail,
                Status = 1, // Pending, NOT approved
                StudentUserID = null,
                CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/Me")
        {
            Headers = { Authorization = new AuthenticationHeaderValue("Bearer", "token-not-approved") }
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);

        using (var db = new TestAppDbContext(options))
        {
            var user = await db.Users.FirstOrDefaultAsync(u => u.FirebaseUID == testUid);
            Assert.Null(user);
        }
    }

    [Fact]
    public async Task Middleware_ApplicationAlreadyLinked_Returns401()
    {
        var testUid = "already-linked-uid-" + Guid.NewGuid();
        var tokenEmail = "linked.student@dbtc-cebu.edu.ph";

        var mock = new Mock<IFirebaseAuthVerifier>();
        mock.Setup(v => v.IsInitialized).Returns(true);
        mock.Setup(v => v.VerifyIdTokenAsync("token-already-linked", true))
            .ReturnsAsync(CreateFakeFirebaseToken(testUid, tokenEmail, emailVerified: true));

        var dbName = "AlreadyLinkedDb_" + Guid.NewGuid();
        using var factory = CreateMiddlewareFactory(dbName, mock);
        var client = factory.CreateClient();

        var options = new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(dbName).Options;
        using (var db = new TestAppDbContext(options))
        {
            var respId = Guid.NewGuid();
            db.EnrollmentResponses.Add(new EnrollmentResponse
            {
                ResponseID = respId,
                EmailAddress = "personal@gmail.com",
                IsProcessed = true,
                Timestamp = DateTime.UtcNow,
                Data = JsonDocument.Parse("{}")
            });
            db.EnrollmentApplications.Add(new EnrollmentApplication
            {
                ApplicationID = Guid.NewGuid(),
                ResponseID = respId,
                SchoolEmail = tokenEmail,
                Status = 2, // Approved
                StudentUserID = Guid.NewGuid(), // Already linked!
                CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/Me")
        {
            Headers = { Authorization = new AuthenticationHeaderValue("Bearer", "token-already-linked") }
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);

        using (var db = new TestAppDbContext(options))
        {
            var user = await db.Users.FirstOrDefaultAsync(u => u.FirebaseUID == testUid);
            Assert.Null(user);
        }
    }

    [Fact]
    public async Task Middleware_UnverifiedEmail_Returns403BeforeAnyDatabaseQuery()
    {
        var testUid = "unverified-firstlogin-uid-" + Guid.NewGuid();
        var tokenEmail = "unverified@dbtc-cebu.edu.ph";

        var mock = new Mock<IFirebaseAuthVerifier>();
        mock.Setup(v => v.IsInitialized).Returns(true);
        mock.Setup(v => v.VerifyIdTokenAsync("token-unverified-firstlogin", true))
            .ReturnsAsync(CreateFakeFirebaseToken(testUid, tokenEmail, emailVerified: false));

        var dbName = "UnverifiedBeforeDbDb_" + Guid.NewGuid();
        using var factory = CreateMiddlewareFactory(dbName, mock);
        var client = factory.CreateClient();

        var options = new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(dbName).Options;
        using (var db = new TestAppDbContext(options))
        {
            var respId = Guid.NewGuid();
            db.EnrollmentResponses.Add(new EnrollmentResponse
            {
                ResponseID = respId,
                EmailAddress = "personal@gmail.com",
                IsProcessed = true,
                Timestamp = DateTime.UtcNow,
                Data = JsonDocument.Parse("{}")
            });
            db.EnrollmentApplications.Add(new EnrollmentApplication
            {
                ApplicationID = Guid.NewGuid(),
                ResponseID = respId,
                SchoolEmail = tokenEmail,
                Status = 2,
                StudentUserID = null,
                CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/Me")
        {
            Headers = { Authorization = new AuthenticationHeaderValue("Bearer", "token-unverified-firstlogin") }
        };

        var response = await client.SendAsync(request);
        // Must be 403 Forbidden with email_not_verified, NOT 401 Unauthorized
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("email_not_verified", body.GetProperty("error").GetString());

        using (var db = new TestAppDbContext(options))
        {
            var user = await db.Users.FirstOrDefaultAsync(u => u.FirebaseUID == testUid);
            Assert.Null(user);
        }
    }
}
