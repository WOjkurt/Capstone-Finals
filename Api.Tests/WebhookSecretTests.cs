using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Api.DTOs.Enrollment;
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

public class WebhookSecretTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;
    private const string ExpectedSecret = "test_forms_wh_sec_mock_for_integration_tests";

    public WebhookSecretTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Testing");
            builder.ConfigureTestServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
                if (descriptor != null)
                {
                    services.Remove(descriptor);
                }
                services.AddDbContext<AppDbContext>(options =>
                {
                    options.UseInMemoryDatabase("WebhookSecretTestDb_" + Guid.NewGuid());
                });

                var mockEnrollmentService = new Mock<IEnrollmentService>();
                mockEnrollmentService
                    .Setup(s => s.CreateResponseAsync(It.IsAny<CreateEnrollmentResponseDto>()))
                    .ReturnsAsync(Guid.NewGuid());

                services.AddScoped(_ => mockEnrollmentService.Object);
            });
        });
    }

    [Fact]
    public async Task WebhookSecret_CorrectSecret_Returns201Created()
    {
        var client = _factory.CreateClient();
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/EnrollmentResponses")
        {
            Content = JsonContent.Create(new CreateEnrollmentResponseDto
            {
                EmailAddress = "test@dbtc-cebu.edu.ph"
            })
        };
        request.Headers.Add("X-Webhook-Secret", ExpectedSecret);

        var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    [Fact]
    public async Task WebhookSecret_WrongSecret_Returns401Unauthorized()
    {
        var client = _factory.CreateClient();
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/EnrollmentResponses")
        {
            Content = JsonContent.Create(new CreateEnrollmentResponseDto
            {
                EmailAddress = "test@dbtc-cebu.edu.ph"
            })
        };
        request.Headers.Add("X-Webhook-Secret", "wrong-secret-value");

        var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Invalid or missing webhook secret.", json.GetProperty("message").GetString());
    }

    [Fact]
    public async Task WebhookSecret_MissingHeader_Returns401Unauthorized()
    {
        var client = _factory.CreateClient();
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/EnrollmentResponses")
        {
            Content = JsonContent.Create(new CreateEnrollmentResponseDto
            {
                EmailAddress = "test@dbtc-cebu.edu.ph"
            })
        };
        // Header X-Webhook-Secret is omitted

        var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Invalid or missing webhook secret.", json.GetProperty("message").GetString());
    }

    [Fact]
    public async Task WebhookSecret_EmptyConfiguration_Returns401Unauthorized()
    {
        var emptyConfigFactory = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, config) =>
            {
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    { "Webhook:GoogleFormsSecret", "" }
                });
            });
        });

        var client = emptyConfigFactory.CreateClient();
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/EnrollmentResponses")
        {
            Content = JsonContent.Create(new CreateEnrollmentResponseDto
            {
                EmailAddress = "test@dbtc-cebu.edu.ph"
            })
        };
        request.Headers.Add("X-Webhook-Secret", ExpectedSecret);

        var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Invalid or missing webhook secret.", json.GetProperty("message").GetString());
    }
}
