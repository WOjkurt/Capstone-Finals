using System.Net;
using System.Security.Cryptography;
using System.Text;
using Api.Auth;
using Api.DTOs.Enrollment;
using Api.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Xunit;

namespace Api.Tests;

/// <summary>Signed Google Form calls: the right signature works; a wrong, old or changed one does not.</summary>
public class WebhookSignatureTests : IClassFixture<WebApplicationFactory<Program>>
{
    private const string Secret = "test_forms_wh_sec_mock_for_integration_tests";
    private const string Body = """{"emailAddress":"applicant@example.com","form":{"firstName":"Niño","lastName":"Peña"}}""";

    private readonly WebApplicationFactory<Program> _factory;
    private readonly Mock<IEnrollmentService> _service = new();

    public WebhookSignatureTests(WebApplicationFactory<Program> factory)
    {
        _service.Setup(s => s.CreateResponseAsync(It.IsAny<CreateEnrollmentResponseDto>())).ReturnsAsync(Guid.NewGuid());
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Testing");
            builder.ConfigureTestServices(services =>
            {
                var options = services.SingleOrDefault(d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
                if (options != null) services.Remove(options);
                services.AddDbContext<AppDbContext>(o => o.UseInMemoryDatabase("WebhookSignature_" + Guid.NewGuid()));
                services.AddScoped(_ => _service.Object);
            });
        });
    }

    private static string Sign(string timestamp, string body, string secret = Secret)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        return "sha256=" + Convert.ToHexStringLower(hmac.ComputeHash(Encoding.UTF8.GetBytes(timestamp + "." + body)));
    }

    private static string Now(int addSeconds = 0) => (DateTimeOffset.UtcNow.ToUnixTimeSeconds() + addSeconds).ToString();

    private async Task<HttpStatusCode> SendAsync(string body, string? timestamp, string? signature,
        string? plainSecret = null, WebApplicationFactory<Program>? factory = null)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/EnrollmentResponses")
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json"),
        };
        if (timestamp != null) request.Headers.Add(RequireWebhookSecretAttribute.TimestampHeader, timestamp);
        if (signature != null) request.Headers.Add(RequireWebhookSecretAttribute.SignatureHeader, signature);
        if (plainSecret != null) request.Headers.Add(RequireWebhookSecretAttribute.SecretHeader, plainSecret);
        return (await (factory ?? _factory).CreateClient().SendAsync(request)).StatusCode;
    }

    [Fact]
    public async Task RightSignature_IsAccepted_AndTheFormIsRead()
    {
        string ts = Now();
        Assert.Equal(HttpStatusCode.Created, await SendAsync(Body, ts, Sign(ts, Body)));
        _service.Verify(s => s.CreateResponseAsync(It.Is<CreateEnrollmentResponseDto>(d =>
            d.EmailAddress == "applicant@example.com" && d.Form!.FirstName == "Niño")), Times.Once);
    }

    [Fact]
    public async Task UppercaseSignature_IsAccepted()
    {
        string ts = Now();
        Assert.Equal(HttpStatusCode.Created, await SendAsync(Body, ts, Sign(ts, Body).ToUpperInvariant()));
    }

    [Fact]
    public async Task ChangedForm_IsRefused()
    {
        string ts = Now();
        string changed = Body.Replace("Peña", "Cruz");
        Assert.Equal(HttpStatusCode.Unauthorized, await SendAsync(changed, ts, Sign(ts, Body)));
        _service.Verify(s => s.CreateResponseAsync(It.IsAny<CreateEnrollmentResponseDto>()), Times.Never);
    }

    [Fact]
    public async Task WrongSecret_IsRefused()
    {
        string ts = Now();
        Assert.Equal(HttpStatusCode.Unauthorized, await SendAsync(Body, ts, Sign(ts, Body, "guessed")));
    }

    [Theory]
    [InlineData(-301)]
    [InlineData(301)]
    public async Task OldOrFutureTimestamp_IsRefused(int seconds)
    {
        string ts = Now(seconds);
        Assert.Equal(HttpStatusCode.Unauthorized, await SendAsync(Body, ts, Sign(ts, Body)));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("yesterday")]
    [InlineData("-5")]
    [InlineData("99999999999999999999")]
    public async Task MissingOrBadTimestamp_IsRefused(string? ts)
    {
        Assert.Equal(HttpStatusCode.Unauthorized, await SendAsync(Body, ts, Sign(ts ?? "", Body)));
    }

    [Fact]
    public async Task ChangedTimestamp_IsRefused()
    {
        string ts = Now();
        Assert.Equal(HttpStatusCode.Unauthorized, await SendAsync(Body, Now(-60), Sign(ts, Body)));
    }

    [Fact]
    public async Task WrongSignature_IsNotRescuedByThePlainSecret()
    {
        Assert.Equal(HttpStatusCode.Unauthorized, await SendAsync(Body, Now(), "sha256=00", plainSecret: Secret));
    }

    [Fact]
    public async Task PlainSecret_StillWorks_UntilItIsSwitchedOff()
    {
        Assert.Equal(HttpStatusCode.Created, await SendAsync(Body, null, null, plainSecret: Secret));

        var signedOnly = _factory.WithWebHostBuilder(b => b.UseSetting("Webhook:AllowPlainSecret", "false"));
        Assert.Equal(HttpStatusCode.Unauthorized, await SendAsync(Body, null, null, Secret, signedOnly));

        string ts = Now();
        Assert.Equal(HttpStatusCode.Created, await SendAsync(Body, ts, Sign(ts, Body), factory: signedOnly));
    }
}
