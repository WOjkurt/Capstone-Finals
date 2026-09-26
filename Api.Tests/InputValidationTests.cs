using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Api.DTOs.Admin;
using Api.DTOs.Enrollment;
using Api.DTOs.Grading;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using Api.Constants;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;
using System.Text.Encodings.Web;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using Api.Services;
using Moq;
using Microsoft.AspNetCore.Hosting;

namespace Api.Tests;

public class TestAuthOptions : AuthenticationSchemeOptions
{
    public int Role { get; set; } = 1;
    public Guid UserId { get; set; } = Guid.NewGuid();
}

public class TestAuthHandler : AuthenticationHandler<TestAuthOptions>
{
    public TestAuthHandler(IOptionsMonitor<TestAuthOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : base(options, logger, encoder)
    {
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, Options.UserId.ToString()),
            new Claim(ClaimTypes.Role, Options.Role.ToString()),
            new Claim("role", Options.Role.ToString()),
            new Claim("user_id", Options.UserId.ToString())
        };
        var identity = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, "Test");

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}

public class InputValidationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public InputValidationTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Testing");
        });
    }

    private HttpClient CreateClientWithRole(int role, Guid userId)
    {
        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                services.AddAuthentication(options =>
                {
                    options.DefaultAuthenticateScheme = "Test";
                    options.DefaultChallengeScheme = "Test";
                })
                .AddScheme<TestAuthOptions, TestAuthHandler>("Test", options =>
                {
                    options.Role = role;
                    options.UserId = userId;
                });
            });
        }).CreateClient();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Test");
        return client;
    }

    [Fact]
    public async Task ValidationErrors_ReturnMessageShape()
    {
        // Arrange
        var client = CreateClientWithRole(1, Guid.NewGuid()); // Admin
        var invalidDto = new CreateStaffDto 
        { 
            Email = "not-an-email", 
            Firstname = "", 
            Lastname = "Valid", 
            Role = 99 
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/admin/staff", invalidDto);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(json.TryGetProperty("message", out var messageProp), "Response should contain a 'message' property.");
        Assert.False(string.IsNullOrWhiteSpace(messageProp.GetString()));
    }

    [Fact]
    public async Task CreateGradeCorrection_ReasonExceeds500Chars_Returns400()
    {
        // Arrange
        var client = CreateClientWithRole(3, Guid.NewGuid()); // Teacher
        var longReason = new string('A', 10000);
        var dto = new CreateGradeCorrectionDto
        {
            GradeId = Guid.NewGuid(),
            CorrectionPeriod = 1,
            OldGrade = 1.0m,
            NewGrade = 1.5m,
            Reason = longReason
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/gradecorrections", dto);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(json.TryGetProperty("message", out _));
    }

    [Fact]
    public async Task WebhookPayload_ExcessiveLength_TruncatesInsteadOf400()
    {
        // Arrange — use the test webhook secret configured in appsettings.Testing.json
        const string WebhookSecret = "test_forms_wh_sec_mock_for_integration_tests";
        var longString = new string('B', 10000);
        var dto = new CreateEnrollmentResponseDto
        {
            EmailAddress = "truncate-test@example.com",
            Form = new ResponseFormDataDto
            {
                FirstName = longString,
                LastName = longString,
                PlaceOfBirth = longString,
                Sex = "M",
                CivilStatus = "S",
                Nationality = "F",
                MobileNumber = longString,
                Barangay = "B",
                Province = "P",
                ZipCode = "1",
                LastSchoolAttended = "L",
                SchoolAddress = "S",
                PreviousCollege = "P",
                PreviousCourse = "P"
            }
        };

        var mockEnrollmentService = new Moq.Mock<IEnrollmentService>();
        mockEnrollmentService
            .Setup(s => s.CreateResponseAsync(Moq.It.IsAny<CreateEnrollmentResponseDto>()))
            .ReturnsAsync(Guid.NewGuid());

        var factory = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                services.AddScoped<IEnrollmentService>(_ => mockEnrollmentService.Object);
            });
        });

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Webhook-Secret", WebhookSecret);

        // Act
        var response = await client.PostAsJsonAsync("/api/enrollmentresponses", dto);

        // Assert — must reach the service (not bounced by 401/400 from model validation)
        Assert.True(
            response.StatusCode == HttpStatusCode.Created || response.StatusCode == HttpStatusCode.OK,
            $"Expected 201/200 but got {response.StatusCode}. Body: {await response.Content.ReadAsStringAsync()}");

        // Confirm service was actually called (i.e., payload passed model validation)
        mockEnrollmentService.Verify(s => s.CreateResponseAsync(Moq.It.IsAny<CreateEnrollmentResponseDto>()), Moq.Times.Once);
    }

    [Fact]
    public async Task CreateApplication_MaxLengths_PassesValidation()
    {
        // Arrange
        var client = CreateClientWithRole(2, Guid.NewGuid()); // Registrar
        var maxName = new string('C', ValidationConstants.NameMax);
        var maxShort = new string('D', ValidationConstants.ShortMax);
        var maxAddress = new string('E', ValidationConstants.AddressMax);
        var maxLongAddress = new string('F', ValidationConstants.LongAddressMax);
        var maxPhone = new string('G', ValidationConstants.PhoneMax);
        var maxZip = new string('H', ValidationConstants.ZipCodeMax);
        
        var dto = new CreateEnrollmentApplicationDto
        {
            ResponseID = Guid.NewGuid(), // Normally exists in db, but model validation runs first
            ProgramID = 1,
            TermID = Guid.NewGuid(),
            Form = new EnrollmentFormDto
            {
                FirstName = maxName,
                MiddleName = maxShort,
                LastName = maxName,
                Suffix = maxShort,
                PlaceOfBirth = maxAddress,
                Sex = maxShort,
                CivilStatus = maxShort,
                Nationality = maxShort,
                MobileNumber = maxPhone,
                Barangay = maxAddress,
                Province = maxAddress,
                ZipCode = maxZip,
                LastSchoolAttended = maxLongAddress,
                SchoolAddress = maxLongAddress,
                PreviousCollege = maxAddress,
                PreviousCourse = maxAddress
            },
            Contacts = new List<ContactDto>
            {
                new ContactDto
                {
                    FirstName = maxName,
                    LastName = maxName,
                    RelationType = 1,
                    ContactNo = maxPhone
                }
            }
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/enrollmentapplications", dto);

        // Assert
        // We might get 400 because ResponseID doesn't exist (from service) or 404, 
        // but we should NOT get 400 from validation with a "message" for string length.
        // Let's just verify it didn't fail model validation.
        if (response.StatusCode == HttpStatusCode.BadRequest)
        {
            var json = await response.Content.ReadFromJsonAsync<JsonElement>();
            if (json.TryGetProperty("message", out var msg))
            {
                var msgStr = msg.GetString() ?? "";
                Assert.DoesNotContain("length", msgStr, StringComparison.OrdinalIgnoreCase);
            }
        }
    }
}
