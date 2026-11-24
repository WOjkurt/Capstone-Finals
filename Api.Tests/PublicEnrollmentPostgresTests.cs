using Api.Domain.Enrollment;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Api.Tests;

/// <summary>
/// The public enrollment form on real PostgreSQL, for the one thing the other tests cannot reach.
///
/// Duplicate detection compares the stored jsonb against the incoming form, and skips any row
/// whose Data is null. TestAppDbContext ignores EnrollmentResponse.Data entirely, because the
/// InMemory provider cannot hold a JsonDocument -- so in every other test the check finds nothing
/// to compare and silently passes. That is exactly the shape of a bug it would never catch:
/// a double-tapped Submit becoming two applications in the Registrar's queue.
///
/// Runs only when TEST_POSTGRES points at a throwaway, migrated database. Row-level security is
/// not covered here: the policies come from the scripts in Migrations/Scripts rather than from an
/// EF migration, and this connects as the owner rather than as dbtc_api.
/// </summary>
public class PublicEnrollmentPostgresTests
{
    private readonly ServiceProvider _root;

    /// <summary>
    /// Far in the future, so this run's enrollment window is the only one near it. Kept under
    /// 9999 because these become real DateOnly values, unlike SchoolYearPostgresTests where the
    /// year only ever appears inside a SchoolYear string and can run far higher.
    /// </summary>
    private readonly int _year = 3000 + Random.Shared.Next(0, 6000);
    private readonly Guid _term = Guid.NewGuid();
    private DateOnly _today;

    public PublicEnrollmentPostgresTests()
    {
        var conn = Environment.GetEnvironmentVariable("TEST_POSTGRES");
        var s = new ServiceCollection();
        s.AddLogging();
        s.AddDbContext<AppDbContext>(o => o.UseNpgsql(conn ?? "Host=none"));
        s.AddScoped<IUserRepository, UserRepository>();
        s.AddScoped<IUserDetailsRepository, UserDetailsRepository>();
        s.AddScoped<IEnrollmentResponseRepository, EnrollmentResponseRepository>();
        s.AddScoped<IEnrollmentApplicationRepository, EnrollmentApplicationRepository>();
        s.AddScoped<IEnrollmentFormRepository, EnrollmentFormRepository>();
        s.AddScoped<IContactRepository, ContactRepository>();
        s.AddScoped<IEnrollmentService, EnrollmentService>();
        s.AddScoped<IPublicEnrollmentService, PublicEnrollmentService>();
        _root = s.BuildServiceProvider();
    }

    /// <summary>A fresh DbContext per step, as a real request gets.</summary>
    private async Task<T> Step<T>(Func<IServiceProvider, Task<T>> work)
    {
        using var scope = _root.CreateScope();
        return await work(scope.ServiceProvider);
    }

    private Task Step(Func<IServiceProvider, Task> work) => Step<object?>(async sp => { await work(sp); return null; });

    private async Task Seed()
    {
        _today = new DateOnly(_year, 6, 15);
        await Step(async sp =>
        {
            var db = sp.GetRequiredService<AppDbContext>();
            db.AcademicTerms.Add(new AcademicTerm
            {
                TermID = _term,
                SchoolYear = $"{_year}-{_year + 1}",
                Semester = 1,
                EnrollmentOpensOn = new DateOnly(_year, 6, 1),
                EnrollmentClosesOn = new DateOnly(_year, 6, 30),
            });
            await db.SaveChangesAsync();
        });
    }

    private string _email = string.Empty;

    private CreateEnrollmentResponseDto Application(string? first = null, string? email = null) => new()
    {
        EmailAddress = email ?? _email,
        Form = new ResponseFormDataDto
        {
            FirstName = first ?? "Ana",
            LastName = "Cruz",
            StudentType = 1,
            IncomingCourse = "BSIT",
            MobileNumber = "09171234567",
            DateOfBirth = "2005-03-14",
            YearGraduated = "2024",
            Barangay = "Pardo",
            CityMunicipality = "Cebu City",
            Province = "Cebu",
            ZipCode = "6000",
        },
        Contacts = new List<ResponseContactDto>
        {
            new() { FirstName = "Pedro", LastName = "Cruz", RelationType = 1, ContactNo = "09170000001" },
        },
    };

    private Task<PublicEnrollmentReceiptDto> Submit(CreateEnrollmentResponseDto dto) =>
        Step(sp => sp.GetRequiredService<IPublicEnrollmentService>().SubmitAsync(dto, _today));

    private Task<List<EnrollmentResponse>> Mine() => Step(async sp =>
        await sp.GetRequiredService<AppDbContext>().EnrollmentResponses
            .AsNoTracking()
            .Where(r => r.EmailAddress == _email)
            .OrderBy(r => r.Timestamp)
            .ToListAsync());

    [PostgresFact]
    public async Task TheFormIsStoredAsJsonb_AndComesBackReadable()
    {
        _email = $"first.{Guid.NewGuid():N}@example.com";
        await Seed();

        var receipt = await Submit(Application());

        var stored = Assert.Single(await Mine());
        Assert.Equal(receipt.ResponseId, stored.ResponseID);
        Assert.False(stored.IsProcessed);

        // The whole point: Data survives the round trip to a jsonb column. Were this null, the
        // duplicate check below would have nothing to compare and would never fire.
        Assert.NotNull(stored.Data);
        var form = stored.Data!.RootElement.GetProperty("form");
        Assert.Equal("Ana", form.GetProperty("firstName").GetString());
        Assert.Equal("2005-03-14", form.GetProperty("dateOfBirth").GetString());
        Assert.Equal($"{_year}-{_year + 1}", form.GetProperty("academicYear").GetString());
        Assert.Equal(1, stored.Data.RootElement.GetProperty("contacts").GetArrayLength());
    }

    [PostgresFact]
    public async Task TheSameFormTwice_IsOneApplication_NotTwo()
    {
        _email = $"double.{Guid.NewGuid():N}@example.com";
        await Seed();

        var first = await Submit(Application());
        var second = await Submit(Application());

        // A double-tapped Submit, or a refreshed page, gives back the application already made.
        Assert.Equal(first.ResponseId, second.ResponseId);
        Assert.Single(await Mine());
    }

    [PostgresFact]
    public async Task TheSameFormWithTheEmailTypedInCapitals_IsStillOneApplication()
    {
        var local = $"capitals.{Guid.NewGuid():N}";
        _email = $"{local}@example.com";
        await Seed();

        var first = await Submit(Application(email: $"{local}@example.com"));
        var second = await Submit(Application(email: $"{local.ToUpperInvariant()}@Example.COM"));

        Assert.Equal(first.ResponseId, second.ResponseId);
        var stored = Assert.Single(await Mine());
        Assert.Equal(_email, stored.EmailAddress);
    }

    [PostgresFact]
    public async Task ACorrectedFormIsKept_BecauseItIsNotTheSameApplication()
    {
        _email = $"corrected.{Guid.NewGuid():N}@example.com";
        await Seed();

        var first = await Submit(Application(first: "Ana"));
        var corrected = await Submit(Application(first: "Anna"));

        Assert.NotEqual(first.ResponseId, corrected.ResponseId);
        var stored = await Mine();
        Assert.Equal(2, stored.Count);
    }

    [PostgresFact]
    public async Task TheSameFormSentAgainAfterADay_IsANewApplication()
    {
        _email = $"nextday.{Guid.NewGuid():N}@example.com";
        await Seed();

        var first = await Submit(Application());

        // The duplicate check only looks back 24 hours, so an applicant who returns the next day
        // and fills the form in identically is making a fresh application, not repeating one.
        await Step(async sp =>
        {
            var db = sp.GetRequiredService<AppDbContext>();
            var row = await db.EnrollmentResponses.SingleAsync(r => r.ResponseID == first.ResponseId);
            row.Timestamp = DateTime.UtcNow.AddHours(-25);
            await db.SaveChangesAsync();
        });

        var again = await Submit(Application());

        Assert.NotEqual(first.ResponseId, again.ResponseId);
        Assert.Equal(2, (await Mine()).Count);
    }

    [PostgresFact]
    public async Task OutsideTheEnrollmentWindow_NothingIsWritten()
    {
        _email = $"closed.{Guid.NewGuid():N}@example.com";
        await Seed();
        _today = new DateOnly(_year, 7, 1);   // the day after it closes

        await Assert.ThrowsAsync<InvalidOperationException>(() => Submit(Application()));

        Assert.Empty(await Mine());
    }

    [PostgresFact]
    public async Task TheStatusEndpointAnswersFromRealData()
    {
        await Seed();

        var status = await Step(sp =>
            sp.GetRequiredService<IPublicEnrollmentService>().GetStatusAsync(_today));

        Assert.True(status.IsOpen);
        Assert.Equal($"{_year}-{_year + 1} (1st Sem)", status.TermLabel);
        Assert.Equal(new DateOnly(_year, 6, 30), status.ClosesOn);
    }
}
