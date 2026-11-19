using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Which browsers are allowed to call the API. A refused origin is invisible in the UI —
/// the page simply comes up empty — so these pin down the rules.
/// </summary>
public class CorsPolicyTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public CorsPolicyTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    // UseSetting, not ConfigureAppConfiguration: Program.cs reads these while the app is
    // being built, which is before an added configuration source would be in place.
    private HttpClient ClientWith(params (string Key, string Value)[] settings) =>
        _factory.WithWebHostBuilder(b =>
        {
            foreach (var (key, value) in settings) b.UseSetting(key, value);
        }).CreateClient();

    /// <summary>The origin the browser would be told it may use, or null when it is refused.</summary>
    private static async Task<string?> PreflightAsync(HttpClient client, string origin)
    {
        var request = new HttpRequestMessage(HttpMethod.Options, "/api/academicprograms");
        request.Headers.Add("Origin", origin);
        request.Headers.Add("Access-Control-Request-Method", "GET");
        request.Headers.Add("Access-Control-Request-Headers", "authorization");
        var response = await client.SendAsync(request);
        return response.Headers.TryGetValues("Access-Control-Allow-Origin", out var values)
            ? values.FirstOrDefault()
            : null;
    }

    private static readonly (string, string)[] OneConfiguredOrigin =
        { ("Cors:AllowedOrigins:0", "http://sis.example.edu") };

    [Fact]
    public async Task AConfiguredOrigin_IsAllowed()
    {
        var client = ClientWith(OneConfiguredOrigin);
        Assert.Equal("http://sis.example.edu", await PreflightAsync(client, "http://sis.example.edu"));
    }

    [Fact]
    public async Task AnUnknownOrigin_IsRefused()
    {
        var client = ClientWith(OneConfiguredOrigin);
        Assert.Null(await PreflightAsync(client, "http://somewhere.else"));
    }

    // The Flutter web dev server picks a random port unless it is given --web-port, so a
    // tester's browser must not depend on which port it happened to choose. These ports are
    // deliberately ones no settings file lists, so only the loopback rule can allow them.
    [Theory]
    [InlineData("http://localhost:61234")]
    [InlineData("http://localhost:49999")]
    [InlineData("http://127.0.0.1:61234")]
    [InlineData("http://127.0.0.1:7001")]
    public async Task AnyPortOnTheTestersOwnMachine_IsAllowed(string origin)
    {
        var client = ClientWith(OneConfiguredOrigin);
        Assert.Equal(origin, await PreflightAsync(client, origin));
    }

    [Fact]
    public async Task LoopbackCanBeTurnedOff_ForARealDeployment()
    {
        var client = ClientWith(
            ("Cors:AllowedOrigins:0", "http://sis.example.edu"),
            ("Cors:AllowLoopback", "false"));

        Assert.Null(await PreflightAsync(client, "http://localhost:61234"));
        Assert.Equal("http://sis.example.edu", await PreflightAsync(client, "http://sis.example.edu"));
    }

    // "localhost" has to be the whole host name, not the start of someone else's.
    [Theory]
    [InlineData("http://localhost.attacker.example")]
    [InlineData("http://notlocalhost")]
    [InlineData("http://127.0.0.1.attacker.example")]
    public async Task AnOriginThatMerelyLooksLocal_IsRefused(string origin)
    {
        var client = ClientWith(OneConfiguredOrigin);
        Assert.Null(await PreflightAsync(client, origin));
    }
}
