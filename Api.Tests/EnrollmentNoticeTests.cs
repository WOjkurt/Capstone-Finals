using Api.Domain.Audit;
using Api.Domain.Enrollment;
using Api.Repositories;
using Api.Services;
using Api.Services.Mail;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Captures what reached the activity log. IActivityLogService is wide -- searching, describing
/// loads and grades -- and only LogAsync matters here, so it wraps a mock rather than reimplementing
/// the rest.
/// </summary>
public class FakeActivityLog
{
    public record Entry(Guid? Actor, string Action, string Summary, Guid? StudentId, Guid? TermId);

    public List<Entry> Entries { get; } = new();
    public bool Fails { get; set; }
    public IActivityLogService Service { get; }

    public FakeActivityLog()
    {
        var mock = new Mock<IActivityLogService>();
        mock.Setup(l => l.LogAsync(It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<Guid?>(), It.IsAny<Guid?>()))
            .Returns((Guid? actor, string action, string summary, Guid? studentId, Guid? termId) =>
            {
                if (Fails) throw new InvalidOperationException("the log is down");
                Entries.Add(new Entry(actor, action, summary, studentId, termId));
                return Task.CompletedTask;
            });
        Service = mock.Object;
    }

    public List<Entry> Of(string action) => Entries.Where(e => e.Action == action).ToList();
}

/// <summary>Records what the school would have sent, so the wording and the timing can be read.</summary>
public class FakeMailer : ISchoolMailer
{
    public record Sent(string To, string Subject, string Body);

    public List<Sent> Messages { get; } = new();
    public bool Fails { get; set; }
    public bool IsConfigured => !Fails;

    public Task<bool> SendAsync(string toAddress, string subject, string body,
        CancellationToken cancellationToken = default)
    {
        if (Fails) return Task.FromResult(false);
        Messages.Add(new Sent(toAddress, subject, body));
        return Task.FromResult(true);
    }
}

/// <summary>
/// Telling an applicant where they stand. They have no school email until the Registrar issues
/// one, so these messages go to the personal address they applied with -- and getting that wrong
/// means either telling nobody, or sending somebody's acceptance to the wrong inbox.
/// </summary>
public class EnrollmentNoticeTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly EnrollmentService _service;
    private readonly FakeMailer _mailer = new();
    private readonly FakeActivityLog _log = new();
    private readonly Guid _registrar = Guid.NewGuid();
    private readonly Guid _term = Guid.NewGuid();
    private const int Program = 1;

    private const string Personal = "applicant@example.com";
    private const string School = "ana.cruz@dbtc-cebu.edu.ph";

    public EnrollmentNoticeTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase("Notices_" + Guid.NewGuid()).Options;
        _context = new TestAppDbContext(options);

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["Auth:AllowedEmailDomain"] = "@dbtc-cebu.edu.ph" })
            .Build();

        _service = new EnrollmentService(
            _context,
            new EnrollmentResponseRepository(_context),
            new EnrollmentApplicationRepository(_context),
            new EnrollmentFormRepository(_context),
            new ContactRepository(_context),
            new UserDetailsRepository(_context),
            new UserRepository(_context),
            NullLogger<EnrollmentService>.Instance,
            config,
            _mailer,
            _log.Service);
    }

    public void Dispose() => _context.Dispose();

    /// <summary>
    /// EnrollmentApplication requires a program and a term, and the repository Includes both, so
    /// a missing one makes the row invisible rather than merely incomplete.
    /// </summary>
    private async Task Reference()
    {
        if (await _context.AcademicTerms.AnyAsync(t => t.TermID == _term)) return;
        _context.AcademicPrograms.Add(new AcademicProgram
        {
            ProgramID = Program, ProgramCode = "BSIT", ProgramName = "BS Information Technology"
        });
        _context.AcademicTerms.Add(new AcademicTerm
        {
            TermID = _term, SchoolYear = "2026-2027", Semester = 1
        });
        await _context.SaveChangesAsync();
    }

    /// <summary>An application waiting on the Registrar, with a personal address on its response.</summary>
    private async Task<Guid> PendingApplication(
        string? personal = Personal, string? schoolEmail = null, bool returning = false, string first = "Ana")
    {
        await Reference();
        var responseId = Guid.NewGuid();
        var applicationId = Guid.NewGuid();

        _context.EnrollmentResponses.Add(new EnrollmentResponse
        {
            ResponseID = responseId,
            EmailAddress = personal ?? string.Empty,
            IsProcessed = true,
            Timestamp = DateTime.UtcNow,
        });
        _context.EnrollmentApplications.Add(new EnrollmentApplication
        {
            ApplicationID = applicationId,
            ResponseID = responseId,
            ProgramID = Program,
            TermID = _term,
            Status = EnrollmentApplicationStatus.Pending,
            SchoolEmail = schoolEmail,
            IsReturning = returning,
            StudentUserID = null,
        });
        _context.EnrollmentForms.Add(new EnrollmentForm
        {
            EnrollmentID = Guid.NewGuid(), ApplicationID = applicationId,
            FirstName = first, MiddleName = "Santos", LastName = "Cruz", Suffix = "N/A",
            DateOfBirth = new DateOnly(2005, 3, 14), PlaceOfBirth = "Cebu City", Sex = "Female",
            CivilStatus = "Single", Nationality = "Filipino", MobileNumber = "09171234567",
            Barangay = "Pardo", CityMunicipality = "Cebu City", Province = "Cebu", ZipCode = "6000",
            LastSchoolAttended = "Abellana NHS", SchoolAddress = "Cebu City",
            YearGraduated = new DateOnly(2024, 3, 1), PreviousCollege = "N/A", PreviousCourse = "N/A",
            AcademicYear = "2026-2027", YearLevel = 1,
        });
        await _context.SaveChangesAsync();
        return applicationId;
    }

    // ── Accepting an application ─────────────────────────────────────────────

    [Fact]
    public async Task Accepting_EmailsThePersonalAddress_BecauseThereIsNoSchoolOneYet()
    {
        var id = await PendingApplication();

        await _service.ApproveApplicationAsync(id, _registrar);

        var sent = Assert.Single(_mailer.Messages);
        Assert.Equal(Personal, sent.To);
        Assert.Contains("accepted", sent.Subject, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("Ana", sent.Body);
        Assert.Contains("2026-2027", sent.Body);
        // Nothing to act on yet, so it says one is coming rather than inventing a next step.
        Assert.Contains("will issue your DBTC school email", sent.Body);
    }

    [Fact]
    public async Task Accepting_WhenTheSchoolEmailIsAlreadySet_SaysWhatItIs()
    {
        var id = await PendingApplication(schoolEmail: School);

        await _service.ApproveApplicationAsync(id, _registrar);

        var sent = Assert.Single(_mailer.Messages);
        Assert.Contains(School, sent.Body);
        Assert.Contains("Sign Up", sent.Body);
    }

    [Fact]
    public async Task Accepting_NeverTellsThemTheyAreEnrolled()
    {
        var id = await PendingApplication();

        await _service.ApproveApplicationAsync(id, _registrar);

        // Approving an application is not enrollment, and the message must not imply it is.
        Assert.Contains("not the same as being enrolled", Assert.Single(_mailer.Messages).Body);
    }

    [Fact]
    public async Task Accepting_AReturningStudent_SendsNothing()
    {
        // They already have an account and a school email; there is nothing to tell them here.
        var id = await PendingApplication(returning: true);
        var application = await _context.EnrollmentApplications.FirstAsync(a => a.ApplicationID == id);
        application.StudentUserID = Guid.NewGuid();
        await _context.SaveChangesAsync();

        await _service.ApproveApplicationAsync(id, _registrar);

        Assert.Empty(_mailer.Messages);
    }

    // ── Mail must never undo what it is announcing ───────────────────────────

    [Fact]
    public async Task Accepting_StillApprovesWhenTheMailFails()
    {
        _mailer.Fails = true;
        var id = await PendingApplication();

        await _service.ApproveApplicationAsync(id, _registrar);

        var application = await _context.EnrollmentApplications.FirstAsync(a => a.ApplicationID == id);
        Assert.Equal(EnrollmentApplicationStatus.Approved, application.Status);
        Assert.Empty(_mailer.Messages);
    }

    [Fact]
    public async Task Accepting_WithNoPersonalAddressOnTheResponse_StillApproves()
    {
        var id = await PendingApplication(personal: null);

        await _service.ApproveApplicationAsync(id, _registrar);

        var application = await _context.EnrollmentApplications.FirstAsync(a => a.ApplicationID == id);
        Assert.Equal(EnrollmentApplicationStatus.Approved, application.Status);
        Assert.Empty(_mailer.Messages);
    }

    // ── Issuing the school email ─────────────────────────────────────────────

    [Fact]
    public async Task IssuingTheSchoolEmail_SendsTheMessageWithSomethingToActOn()
    {
        var id = await PendingApplication();

        await _service.UpdateSchoolEmailAsync(id, School, _registrar);

        var sent = Assert.Single(_mailer.Messages);
        Assert.Equal(Personal, sent.To);
        Assert.Contains("school email", sent.Subject, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(School, sent.Body);
        Assert.Contains("Sign Up", sent.Body);
    }

    [Fact]
    public async Task ResavingTheSameSchoolEmail_DoesNotTellThemAgain()
    {
        var id = await PendingApplication();

        await _service.UpdateSchoolEmailAsync(id, School, _registrar);
        await _service.UpdateSchoolEmailAsync(id, School, _registrar);
        // Different capitals, same address once normalised.
        await _service.UpdateSchoolEmailAsync(id, School.ToUpperInvariant(), _registrar);

        // The Registrar re-saves this screen while fixing other details. Three identical
        // "your school email is X" messages would read like something had gone wrong.
        Assert.Single(_mailer.Messages);
    }

    [Fact]
    public async Task CorrectingTheSchoolEmailToADifferentOne_TellsThemTheNewOne()
    {
        var id = await PendingApplication();

        await _service.UpdateSchoolEmailAsync(id, School, _registrar);
        await _service.UpdateSchoolEmailAsync(id, "ana.c.cruz@dbtc-cebu.edu.ph", _registrar);

        Assert.Equal(2, _mailer.Messages.Count);
        Assert.Contains("ana.c.cruz@dbtc-cebu.edu.ph", _mailer.Messages[1].Body);
    }

    [Fact]
    public async Task ClearingThenReissuingTheSameAddress_TellsThemAgain()
    {
        // They were told, then it was taken away; being told again is correct here.
        var id = await PendingApplication(schoolEmail: School);

        await _service.UpdateSchoolEmailAsync(id, null, _registrar);
        await _service.UpdateSchoolEmailAsync(id, School, _registrar);

        Assert.Single(_mailer.Messages);
    }

    [Fact]
    public async Task ClearingTheSchoolEmail_TellsNobodyAnything()
    {
        var id = await PendingApplication(schoolEmail: School);

        await _service.UpdateSchoolEmailAsync(id, null, _registrar);

        Assert.Empty(_mailer.Messages);
    }

    [Fact]
    public async Task AcceptingThenIssuing_SendsBothMessages_InThatOrder()
    {
        // The order the Registrar usually works in: accept now, issue the address later.
        var id = await PendingApplication();

        await _service.ApproveApplicationAsync(id, _registrar);
        await _service.UpdateSchoolEmailAsync(id, School, _registrar);

        Assert.Equal(2, _mailer.Messages.Count);
        Assert.Contains("accepted", _mailer.Messages[0].Subject, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(School, _mailer.Messages[1].Body);
        Assert.All(_mailer.Messages, m => Assert.Equal(Personal, m.To));
    }

    [Fact]
    public async Task ARejectedSchoolEmail_SendsNothing()
    {
        var id = await PendingApplication();

        await Assert.ThrowsAsync<ArgumentException>(
            () => _service.UpdateSchoolEmailAsync(id, "someone@gmail.com", _registrar));

        Assert.Empty(_mailer.Messages);
    }

    // ── The wording itself ───────────────────────────────────────────────────

    [Fact]
    public void ANoticeGreetsSomebodyWithNoFirstNameOnRecord_WithoutALeftoverBlank()
    {
        var (_, body) = EnrollmentNotices.Accepted(null, "2026-2027", null);

        Assert.StartsWith("Hello,", body);
        Assert.DoesNotContain("Hello ,", body);
    }

    [Fact]
    public void ANoticeSaysNotToReplyToIt_BecauseNobodyReadsThatMailbox()
    {
        foreach (var body in new[]
                 {
                     EnrollmentNotices.Accepted("Ana", "2026-2027", null).Body,
                     EnrollmentNotices.SchoolEmailReady("Ana", School).Body,
                 })
        {
            Assert.Contains("do not reply", body, StringComparison.OrdinalIgnoreCase);
            Assert.Contains("Registrar", body);
        }
    }

    // ── What the Registrar can see afterwards ───────────────────────────────

    [Fact]
    public async Task AnEmailThatWentOut_IsRecordedWithTheAddressItWentTo()
    {
        var id = await PendingApplication();

        await _service.ApproveApplicationAsync(id, _registrar);

        var entry = Assert.Single(_log.Of(ActivityActions.ApplicantNotified));
        Assert.Equal(_registrar, entry.Actor);
        // The address is the point: a typo in it is the usual reason an applicant was not reached.
        Assert.Contains(Personal, entry.Summary);
        Assert.Contains("Emailed", entry.Summary);
    }

    [Fact]
    public async Task AnEmailThatFailed_IsRecordedAsNeedingAnotherWay()
    {
        _mailer.Fails = true;
        var id = await PendingApplication();

        await _service.ApproveApplicationAsync(id, _registrar);

        var entry = Assert.Single(_log.Of(ActivityActions.ApplicantNotified));
        Assert.Contains("Could not email", entry.Summary);
        Assert.Contains("another way", entry.Summary);
    }

    [Fact]
    public async Task AnApplicationWithNoAddressAtAll_SaysThatRatherThanNothing()
    {
        var id = await PendingApplication(personal: null);

        await _service.ApproveApplicationAsync(id, _registrar);

        var entry = Assert.Single(_log.Of(ActivityActions.ApplicantNotified));
        Assert.Contains("no personal email", entry.Summary);
    }

    [Fact]
    public async Task IssuingTheSchoolEmail_RecordsBothTheChangeAndTheEmail()
    {
        var id = await PendingApplication();

        await _service.UpdateSchoolEmailAsync(id, School, _registrar);

        // The change of address that owns a student's records left no trace before this.
        var change = Assert.Single(_log.Of(ActivityActions.SchoolEmailSet));
        Assert.Equal(_registrar, change.Actor);
        Assert.Contains(School, change.Summary);

        var told = Assert.Single(_log.Of(ActivityActions.ApplicantNotified));
        Assert.Contains(Personal, told.Summary);
    }

    [Fact]
    public async Task ClearingTheSchoolEmail_IsRecordedButTellsNobody()
    {
        var id = await PendingApplication(schoolEmail: School);

        await _service.UpdateSchoolEmailAsync(id, null, _registrar);

        Assert.Contains("cleared", Assert.Single(_log.Of(ActivityActions.SchoolEmailSet)).Summary);
        Assert.Empty(_log.Of(ActivityActions.ApplicantNotified));
    }

    [Fact]
    public async Task ResavingTheSameSchoolEmail_IsRecordedOnceEachTime_ButOnlyEmailsOnce()
    {
        var id = await PendingApplication();

        await _service.UpdateSchoolEmailAsync(id, School, _registrar);
        await _service.UpdateSchoolEmailAsync(id, School, _registrar);

        // Two saves really happened, so two traces; only one of them told the applicant anything.
        Assert.Equal(2, _log.Of(ActivityActions.SchoolEmailSet).Count);
        Assert.Single(_log.Of(ActivityActions.ApplicantNotified));
    }

    [Fact]
    public async Task ALogThatIsDown_DoesNotUndoTheApprovalOrTheEmail()
    {
        _log.Fails = true;
        var id = await PendingApplication();

        await _service.ApproveApplicationAsync(id, _registrar);

        var application = await _context.EnrollmentApplications.FirstAsync(a => a.ApplicationID == id);
        Assert.Equal(EnrollmentApplicationStatus.Approved, application.Status);
        Assert.Single(_mailer.Messages);
    }

    /// <summary>
    /// The mailer and the activity log are OPTIONAL trailing constructor parameters, so if the
    /// container stopped filling them every test here would still pass -- they pass their own --
    /// while in production no applicant was emailed and nothing was recorded. This is the only
    /// test that would notice.
    /// </summary>
    [Fact]
    public void TheContainerFillsBothOptionalDependencies()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton<IConfiguration>(new ConfigurationBuilder().Build());
        services.AddDbContext<AppDbContext>(o => o.UseInMemoryDatabase("Wiring_" + Guid.NewGuid()));
        services.AddScoped<Api.Repositories.IEnrollmentResponseRepository, Api.Repositories.EnrollmentResponseRepository>();
        services.AddScoped<Api.Repositories.IEnrollmentApplicationRepository, Api.Repositories.EnrollmentApplicationRepository>();
        services.AddScoped<Api.Repositories.IEnrollmentFormRepository, Api.Repositories.EnrollmentFormRepository>();
        services.AddScoped<Api.Repositories.IContactRepository, Api.Repositories.ContactRepository>();
        services.AddScoped<Api.Repositories.IUserDetailsRepository, Api.Repositories.UserDetailsRepository>();
        services.AddScoped<Api.Repositories.IUserRepository, Api.Repositories.UserRepository>();
        services.AddScoped<ISchoolMailer, UnconfiguredSchoolMailer>();
        services.AddScoped<IActivityLogService>(_ => new FakeActivityLog().Service);
        services.AddScoped<IEnrollmentService, EnrollmentService>();

        using var provider = services.BuildServiceProvider();
        using var scope = provider.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<IEnrollmentService>();

        foreach (var field in new[] { "_mailer", "_activityLog" })
        {
            var value = typeof(EnrollmentService)
                .GetField(field, System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)!
                .GetValue(service);
            Assert.NotNull(value);
        }
    }

    [Fact]
    public void TheNewActionIsInTheRegistryTheActivityScreenReadsFrom()
    {
        Assert.Contains(ActivityActions.ApplicantNotified, ActivityActions.All);
    }

    // ── Nothing is sent unless a mail account is configured ──────────────────

    [Theory]
    [InlineData("not an email")]
    [InlineData("a@@b.com")]
    [InlineData("<script>@x.com")]
    [InlineData("two@addresses.com, other@x.com")]
    [InlineData("")]
    public async Task AMalformedAddress_ReportsFailureRatherThanThrowing(string address)
    {
        // Addresses recorded before the public form existed were never checked, so a response can
        // hold anything. Sending must report failure, because callers rely on it not throwing to
        // keep an approval from being undone by an unsendable notice.
        var mailer = new SmtpSchoolMailer(
            Config("smtp.invalid", "noreply@dbtc-cebu.edu.ph", "app-password"),
            NullLogger<SmtpSchoolMailer>.Instance);

        Assert.False(await mailer.SendAsync(address, "Subject", "Body"));
    }

    [Fact]
    public async Task AnUnconfiguredMailer_SendsNothingAndSaysSo()
    {
        var mailer = new UnconfiguredSchoolMailer(NullLogger<UnconfiguredSchoolMailer>.Instance);

        Assert.False(mailer.IsConfigured);
        Assert.False(await mailer.SendAsync(Personal, "Subject", "Body"));
    }

    [Theory]
    [InlineData(null, "user@dbtc-cebu.edu.ph", "secret")]   // no host
    [InlineData("smtp.gmail.com", null, "secret")]          // no account
    [InlineData("smtp.gmail.com", "user@dbtc-cebu.edu.ph", null)]  // no app password
    public void TheSmtpMailerIsNotConfigured_UntilEveryPartIsPresent(string? host, string? user, string? password)
    {
        var mailer = new SmtpSchoolMailer(Config(host, user, password), NullLogger<SmtpSchoolMailer>.Instance);

        Assert.False(mailer.IsConfigured);
    }

    [Fact]
    public void TheSmtpMailerIsConfigured_OnceHostAccountAndPasswordAreSet()
    {
        var mailer = new SmtpSchoolMailer(
            Config("smtp.gmail.com", "noreply@dbtc-cebu.edu.ph", "app-password"),
            NullLogger<SmtpSchoolMailer>.Instance);

        Assert.True(mailer.IsConfigured);
    }

    private static IConfiguration Config(string? host, string? user, string? password) =>
        new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Mail:Host"] = host,
            ["Mail:Username"] = user,
            ["Mail:Password"] = password,
        }).Build();
}
