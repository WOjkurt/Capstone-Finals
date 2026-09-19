using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Xunit;

namespace Api.Tests;

public class RateLimitingTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public RateLimitingTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Testing");
            builder.ConfigureTestServices(services =>
            {
                // Swap DbContext to InMemory to prevent real database network calls during tests
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
                if (descriptor != null)
                {
                    services.Remove(descriptor);
                }
                services.AddDbContext<AppDbContext>(options =>
                {
                    options.UseInMemoryDatabase("RateLimitingTestDb_" + Guid.NewGuid());
                });

                // Mock enrollment service to return a successful response ID
                var mockEnrollmentService = new Mock<IEnrollmentService>();
                mockEnrollmentService
                    .Setup(s => s.CreateResponseAsync(It.IsAny<CreateEnrollmentResponseDto>()))
                    .ReturnsAsync(Guid.NewGuid());

                services.AddScoped(_ => mockEnrollmentService.Object);
            });
        });
    }

    private static HttpRequestMessage CreateWebhookRequest(string clientIp)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/EnrollmentResponses")
        {
            Content = JsonContent.Create(new CreateEnrollmentResponseDto
            {
                EmailAddress = "john.doe@example.com"
            })
        };

        // Forwarded headers simulating Render reverse proxy
        request.Headers.Add("X-Forwarded-For", clientIp);
        request.Headers.Add("X-Forwarded-Proto", "https");
        request.Headers.Add("X-Webhook-Secret", "dbtc_forms_wh_sec_7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d");

        return request;
    }

    [Fact]
    public async Task Webhook_NormalCall_ReturnsExpectedCreatedStatus()
    {
        // Arrange
        var client = _factory.CreateClient();
        var uniqueIp = "192.0.2.1"; // Dedicated test IP
        using var request = CreateWebhookRequest(uniqueIp);

        // Act
        var response = await client.SendAsync(request);

        // Assert — Under the limit returns 201 Created (expected normal response)
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    [Fact]
    public async Task Webhook_61stCallInMinute_Returns429WithSanitizedJsonAndRetryAfter()
    {
        // Arrange — configure WebhookPermitLimit = 5 to keep test fast
        var customFactory = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((ctx, config) =>
            {
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["RateLimiting:WebhookPermitLimit"] = "5"
                });
            });
        });
        var client = customFactory.CreateClient();
        var clientIp = "198.51.100.50"; // Unique IP for this test case

        // Act: Send 5 calls (all within the configured limit)
        for (int i = 1; i <= 5; i++)
        {
            using var req = CreateWebhookRequest(clientIp);
            var res = await client.SendAsync(req);
            Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        }

        // Act: 6th call exceeds the 5 requests/minute webhook policy
        using var overLimitReq = CreateWebhookRequest(clientIp);
        var rateLimitedResponse = await client.SendAsync(overLimitReq);

        // Assert — 429 Too Many Requests
        Assert.Equal((HttpStatusCode)429, rateLimitedResponse.StatusCode);

        // Assert — Retry-After header present
        Assert.True(rateLimitedResponse.Headers.Contains("Retry-After"), "Expected Retry-After header on 429 response.");
        var retryAfterVal = rateLimitedResponse.Headers.GetValues("Retry-After").FirstOrDefault();
        Assert.False(string.IsNullOrWhiteSpace(retryAfterVal), "Retry-After header value should not be empty.");

        // Assert — JSON body {"message":"Too many requests. Try again later."}
        var body = await rateLimitedResponse.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(body);
        Assert.True(doc.RootElement.TryGetProperty("message", out var msgElem));
        Assert.Equal("Too many requests. Try again later.", msgElem.GetString());
    }

    [Fact]
    public async Task Webhook_DifferentClientIP_GetsSeparateRateLimitQuota()
    {
        // Arrange — use a small limit so the test stays fast
        var customFactory = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((ctx, config) =>
            {
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["RateLimiting:WebhookPermitLimit"] = "3"
                });
            });
        });
        var client = customFactory.CreateClient();
        var exhaustedIp = "203.0.113.10";
        var freshIp = "203.0.113.20";

        // Exhaust quota for exhaustedIp (3 calls)
        for (int i = 1; i <= 3; i++)
        {
            using var req = CreateWebhookRequest(exhaustedIp);
            var res = await client.SendAsync(req);
            Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        }

        // 4th call for exhaustedIp should be 429
        using var blockedReq = CreateWebhookRequest(exhaustedIp);
        var blockedRes = await client.SendAsync(blockedReq);
        Assert.Equal((HttpStatusCode)429, blockedRes.StatusCode);

        // Call from a distinct IP should still succeed with 201 Created
        using var freshReq = CreateWebhookRequest(freshIp);
        var freshRes = await client.SendAsync(freshReq);
        Assert.Equal(HttpStatusCode.Created, freshRes.StatusCode);
    }

    [Fact]
    public async Task RateLimiting_ConfigurableLimits_RespectsAppsettingsConfiguration()
    {
        // Arrange — override configuration to set WebhookPermitLimit = 3
        var customFactory = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((ctx, config) =>
            {
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["RateLimiting:WebhookPermitLimit"] = "3"
                });
            });
        });

        var client = customFactory.CreateClient();
        var clientIp = "198.51.100.99";

        // Act: 3 calls succeed under custom limit
        for (int i = 1; i <= 3; i++)
        {
            using var req = CreateWebhookRequest(clientIp);
            var res = await client.SendAsync(req);
            Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        }

        // 4th call exceeds the configured limit of 3
        using var fourthReq = CreateWebhookRequest(clientIp);
        var fourthRes = await client.SendAsync(fourthReq);

        // Assert — 429 Too Many Requests
        Assert.Equal((HttpStatusCode)429, fourthRes.StatusCode);
    }

    [Fact]
    public void EnrollmentResponses_CreateResponse_HasWebhookRateLimitingAttribute()
    {
        var method = typeof(Api.Controllers.EnrollmentResponsesController).GetMethod(nameof(Api.Controllers.EnrollmentResponsesController.CreateResponse));
        var attr = method?.GetCustomAttributes(typeof(Microsoft.AspNetCore.RateLimiting.EnableRateLimitingAttribute), inherit: false)
            .Cast<Microsoft.AspNetCore.RateLimiting.EnableRateLimitingAttribute>()
            .FirstOrDefault();

        Assert.NotNull(attr);
        Assert.Equal("webhook", attr.PolicyName);
    }

    [Fact]
    public void UserDetails_Search_HasSearchRateLimitingAttribute()
    {
        var method = typeof(Api.Controllers.UserDetailsController).GetMethod(nameof(Api.Controllers.UserDetailsController.Search));
        var attr = method?.GetCustomAttributes(typeof(Microsoft.AspNetCore.RateLimiting.EnableRateLimitingAttribute), inherit: false)
            .Cast<Microsoft.AspNetCore.RateLimiting.EnableRateLimitingAttribute>()
            .FirstOrDefault();

        Assert.NotNull(attr);
        Assert.Equal("search", attr.PolicyName);
    }

    [Fact]
    public async Task Search_ExceedingConfiguredLimit_Returns429()
    {
        // Arrange — configure SearchPermitLimit = 2
        var searchFactory = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((ctx, config) =>
            {
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["RateLimiting:SearchPermitLimit"] = "2"
                });
            });
        });

        var client = searchFactory.CreateClient();
        var clientIp = "192.0.2.77";

        // First 2 requests: rate limiter permits them (even if auth fails with 401, rate limiter evaluated and passed)
        for (int i = 1; i <= 2; i++)
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, "/api/userdetails");
            req.Headers.Add("X-Forwarded-For", clientIp);
            var res = await client.SendAsync(req);
            Assert.NotEqual((HttpStatusCode)429, res.StatusCode);
        }

        // 3rd request exceeds limit of 2
        using var thirdReq = new HttpRequestMessage(HttpMethod.Get, "/api/userdetails");
        thirdReq.Headers.Add("X-Forwarded-For", clientIp);
        var thirdRes = await client.SendAsync(thirdReq);

        // Assert — 429 Too Many Requests
        Assert.Equal((HttpStatusCode)429, thirdRes.StatusCode);
        Assert.True(thirdRes.Headers.Contains("Retry-After"));
    }

    /// <summary>
    /// Security test: a fake (unsigned) JWT that changes its sub claim on every request
    /// must NOT bypass rate limiting. Since the search policy now partitions by IP only,
    /// all these requests share the same bucket and the limit is still hit.
    /// </summary>
    [Fact]
    public async Task Search_FakeUnsignedTokenWithDifferentSubPerRequest_StillLimitedByIP()
    {
        // Arrange — configure SearchPermitLimit = 2
        var searchFactory = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((ctx, config) =>
            {
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["RateLimiting:SearchPermitLimit"] = "2"
                });
            });
        });
        var client = searchFactory.CreateClient();
        var sharedIp = "192.0.2.88";

        static string MakeFakeToken(string sub)
        {
            // Build a fake JWT header.payload.signature with a unique sub each time.
            // The signature is NOT valid — the rate limiter must NOT trust it.
            var header = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("{\"alg\":\"HS256\",\"typ\":\"JWT\"}")).TrimEnd('=');
            var payload = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{{\"sub\":\"{sub}\",\"user_id\":\"{sub}\"}}")).TrimEnd('=');
            return $"{header}.{payload}.fakesignature";
        }

        // First 2 requests (each with a DIFFERENT sub) — limiter should allow them
        for (int i = 1; i <= 2; i++)
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, "/api/userdetails");
            req.Headers.Add("X-Forwarded-For", sharedIp);
            req.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", MakeFakeToken(Guid.NewGuid().ToString()));
            var res = await client.SendAsync(req);
            Assert.NotEqual((HttpStatusCode)429, res.StatusCode);
        }

        // 3rd request — same IP, different fake sub — must be rate-limited (IP bucket exhausted)
        using var thirdReq = new HttpRequestMessage(HttpMethod.Get, "/api/userdetails");
        thirdReq.Headers.Add("X-Forwarded-For", sharedIp);
        thirdReq.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", MakeFakeToken(Guid.NewGuid().ToString()));
        var thirdRes = await client.SendAsync(thirdReq);

        // Assert — 429: the fake token's sub did NOT create a separate bucket
        Assert.Equal((HttpStatusCode)429, thirdRes.StatusCode);
        Assert.True(thirdRes.Headers.Contains("Retry-After"));
    }
}
