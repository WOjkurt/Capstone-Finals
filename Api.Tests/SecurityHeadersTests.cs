using System.Net;
using System.Reflection;
using Api.Auth;
using Api.DTOs.Setup;
using Api.Services;
using FirebaseAdmin.Auth;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Xunit;

namespace Api.Tests;

public class SecurityHeadersTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public SecurityHeadersTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    private static void AssertSecurityHeaders(HttpResponseMessage response)
    {
        Assert.True(response.Headers.TryGetValues("X-Content-Type-Options", out var ctValues), "Missing X-Content-Type-Options");
        Assert.Equal("nosniff", ctValues.FirstOrDefault());

        Assert.True(response.Headers.TryGetValues("X-Frame-Options", out var foValues), "Missing X-Frame-Options");
        Assert.Equal("DENY", foValues.FirstOrDefault());

        Assert.True(response.Headers.TryGetValues("Referrer-Policy", out var rpValues), "Missing Referrer-Policy");
        Assert.Equal("no-referrer", rpValues.FirstOrDefault());

        Assert.True(response.Headers.TryGetValues("Content-Security-Policy", out var cspValues), "Missing Content-Security-Policy");
        Assert.Equal("default-src 'none'; frame-ancestors 'none'", cspValues.FirstOrDefault());

        Assert.True(response.Headers.TryGetValues("Cache-Control", out var ccValues), "Missing Cache-Control");
        Assert.Contains("no-store", ccValues.FirstOrDefault() ?? "");

        Assert.True(response.Headers.TryGetValues("Pragma", out var pragmaValues), "Missing Pragma");
        Assert.Equal("no-cache", pragmaValues.FirstOrDefault());
    }

    private static FirebaseToken CreateFakeFirebaseToken(string uid, string email)
    {
        var argsType = typeof(FirebaseToken).GetNestedType("Args", BindingFlags.Public | BindingFlags.NonPublic)!;
        var args = Activator.CreateInstance(argsType, true)!;
        argsType.GetProperty("Subject", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)!
            .SetValue(args, uid);

        var claims = new Dictionary<string, object>
        {
            { "email", email },
            { "email_verified", true }
        };
        argsType.GetProperty("Claims", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)!
            .SetValue(args, claims);

        var ctor = typeof(FirebaseToken).GetConstructor(
            BindingFlags.NonPublic | BindingFlags.Instance,
            null,
            new[] { argsType },
            null)!;
        return (FirebaseToken)ctor.Invoke(new[] { args });
    }

    [Fact]
    public async Task SecurityHeaders_On401Unauthorized_ArePresent()
    {
        var client = _factory.CreateClient();

        // No token provided to protected endpoint -> 401
        var response = await client.GetAsync("/api/Me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        AssertSecurityHeaders(response);
    }

    private static void ReplaceDbWithInMemory(IServiceCollection services, string dbName)
    {
        var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
        if (descriptor != null) services.Remove(descriptor);
        var dbDescriptor = services.SingleOrDefault(d => d.ServiceType == typeof(AppDbContext));
        if (dbDescriptor != null) services.Remove(dbDescriptor);

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(dbName)
            .Options;

        services.AddScoped<AppDbContext>(_ => new TestAppDbContext(options));
    }

    [Fact]
    public async Task SecurityHeaders_On200Ok_ArePresent()
    {
        var mockVerifier = new Mock<IFirebaseAuthVerifier>();
        mockVerifier.Setup(v => v.IsInitialized).Returns(true);
        var token = CreateFakeFirebaseToken("user-200-uid", "student.headers@dbtc-cebu.edu.ph");
        mockVerifier.Setup(v => v.VerifyIdTokenAsync("valid-token", true))
            .ReturnsAsync(token);

        var dbName = "SecHeaders200Db_" + Guid.NewGuid();
        var testFactory = _factory.WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Testing");
            builder.ConfigureTestServices(services =>
            {
                ReplaceDbWithInMemory(services, dbName);
                services.AddSingleton(mockVerifier.Object);
            });
        });

        // Seed user in in-memory DB
        using (var scope = testFactory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Users.Add(new Domain.IdentityAccess.User
            {
                UserID = Guid.NewGuid(),
                FirebaseUID = "user-200-uid",
                Email = "student.headers@dbtc-cebu.edu.ph",
                Role = RoleUtils.Student,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }

        var client = testFactory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", "valid-token");

        var response = await client.GetAsync("/api/Me");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        AssertSecurityHeaders(response);
    }

    [Fact]
    public async Task SecurityHeaders_On500InternalServerError_ArePresent()
    {
        var dbName = "SecHeaders500Db_" + Guid.NewGuid();
        var testFactory = _factory.WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Testing"); // Ensures UseExceptionHandler runs without developer exception page
            builder.ConfigureTestServices(services =>
            {
                ReplaceDbWithInMemory(services, dbName);

                // Mock service to throw unhandled exception
                var mockProgramService = new Mock<IAcademicProgramService>();
                mockProgramService.Setup(s => s.GetAllAsync())
                    .ThrowsAsync(new InvalidOperationException("Unhandled server explosion!"));
                services.AddScoped(_ => mockProgramService.Object);

                var mockVerifier = new Mock<IFirebaseAuthVerifier>();
                mockVerifier.Setup(v => v.IsInitialized).Returns(true);
                mockVerifier.Setup(v => v.VerifyIdTokenAsync(It.IsAny<string>(), true))
                    .ReturnsAsync(CreateFakeFirebaseToken("uid-500", "admin@dbtc-cebu.edu.ph"));
                services.AddSingleton(mockVerifier.Object);
            });
        });

        using (var scope = testFactory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Users.Add(new Domain.IdentityAccess.User
            {
                UserID = Guid.NewGuid(),
                FirebaseUID = "uid-500",
                Email = "admin@dbtc-cebu.edu.ph",
                Role = RoleUtils.Admin,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }

        var client = testFactory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", "any-token");

        var response = await client.GetAsync("/api/AcademicPrograms");

        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
        AssertSecurityHeaders(response);
    }

    [Fact]
    public async Task SecurityHeaders_CorsPreflight_WorksAndCarriesHeaders()
    {
        var client = _factory.CreateClient();
        var request = new HttpRequestMessage(HttpMethod.Options, "/api/Me");
        request.Headers.Add("Origin", "http://localhost:3000");
        request.Headers.Add("Access-Control-Request-Method", "GET");

        var response = await client.SendAsync(request);

        Assert.True(response.StatusCode == HttpStatusCode.OK || response.StatusCode == HttpStatusCode.NoContent);
        Assert.True(response.Headers.Contains("Access-Control-Allow-Origin"));
        Assert.Equal("http://localhost:3000", response.Headers.GetValues("Access-Control-Allow-Origin").FirstOrDefault());
        AssertSecurityHeaders(response);
    }

    [Fact]
    public async Task Hsts_NonDevelopmentWithForwardedProtoHttps_ReturnsHstsHeader()
    {
        // Making the test host non-Development using builder.UseEnvironment("Staging")
        var nonDevFactory = _factory.WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Staging");
            builder.ConfigureAppConfiguration((_, config) =>
            {
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    { "Firebase:ProjectId", "" },
                    { "Firebase:ServiceAccountKeyPath", "" },
                    { "ConnectionStrings:DefaultConnection", "Host=localhost;Database=testing_db;Username=test;Password=test" }
                });
            });
            builder.ConfigureTestServices(services =>
            {
                ReplaceDbWithInMemory(services, "HstsWithProto_" + Guid.NewGuid());
            });
        });

        var client = nonDevFactory.CreateClient();

        // 1. Request with X-Forwarded-Proto: https
        var httpsRequest = new HttpRequestMessage(HttpMethod.Get, "/api/Me");
        httpsRequest.Headers.Add("X-Forwarded-Proto", "https");
        var httpsResponse = await client.SendAsync(httpsRequest);

        Assert.True(httpsResponse.Headers.Contains("Strict-Transport-Security"), "Expected Strict-Transport-Security header when X-Forwarded-Proto is https");
        var hstsValue = httpsResponse.Headers.GetValues("Strict-Transport-Security").FirstOrDefault();
        Assert.Equal("max-age=15552000", hstsValue);
        Assert.DoesNotContain("includeSubDomains", hstsValue);
        Assert.DoesNotContain("preload", hstsValue);

        // 2. Request without X-Forwarded-Proto: https (plain HTTP request)
        var httpRequest = new HttpRequestMessage(HttpMethod.Get, "/api/Me");
        var httpResponse = await client.SendAsync(httpRequest);

        Assert.False(httpResponse.Headers.Contains("Strict-Transport-Security"), "Strict-Transport-Security must NOT be returned for non-HTTPS requests");
    }
}
