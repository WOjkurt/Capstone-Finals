using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using Api.Constants;
using Api.Domain.Enrollment;
using Api.DTOs.Admin;
using Api.DTOs.Class;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Api.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;
using Xunit.Abstractions;

namespace Api.Tests;

/// <summary>
/// Unit tests for EnrollmentService.SanitizeWebhookPayload (called via CreateResponseAsync)
/// and for the DaysOfWeek regex on CreateClassScheduleDto.
/// </summary>
public class EnrollmentServiceSanitizeTests
{
    // ── Helpers ───────────────────────────────────────────────────────────────

    private static (EnrollmentService service, Mock<IEnrollmentResponseRepository> repoMock) BuildService(
        ILogger<EnrollmentService>? logger = null)
    {
        var repoMock = new Mock<IEnrollmentResponseRepository>();
        repoMock.Setup(r => r.AddAsync(It.IsAny<EnrollmentResponse>()))
                .Returns(Task.CompletedTask);

        var svc = new EnrollmentService(
            new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase("Sanitize_" + Guid.NewGuid()).Options),
            repoMock.Object,
            new Mock<IEnrollmentApplicationRepository>().Object,
            new Mock<IEnrollmentFormRepository>().Object,
            new Mock<IContactRepository>().Object,
            new Mock<IUserDetailsRepository>().Object,
            new Mock<IUserRepository>().Object,
            logger ?? NullLogger<EnrollmentService>.Instance);

        return (svc, repoMock);
    }

    /// <summary>Deserialise the captured jsonb Data back into ResponseFormDataDto for assertions.</summary>
    private static ResponseFormDataDto? ExtractForm(EnrollmentResponse captured)
    {
        if (captured.Data == null) return null;
        var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        return JsonSerializer.Deserialize<ResponseDataDto>(captured.Data.RootElement.GetRawText(), opts)?.Form;
    }

    [Fact]
    public async Task CreateResponse_NamesLoseAccents_OtherFieldsKeepThem()
    {
        var (service, repo) = BuildService();
        EnrollmentResponse? saved = null;
        repo.Setup(r => r.AddAsync(It.IsAny<EnrollmentResponse>()))
            .Callback<EnrollmentResponse>(r => saved = r)
            .Returns(Task.CompletedTask);

        await service.CreateResponseAsync(new CreateEnrollmentResponseDto
        {
            EmailAddress = "applicant@example.com",
            Form = new ResponseFormDataDto { FirstName = "José", LastName = "Peña", PlaceOfBirth = "Parañaque, José Panganiban" },
            Contacts = [new ResponseContactDto { FirstName = "María", LastName = "Núñez" }],
        });

        var form = ExtractForm(saved!)!;
        var contact = Assert.Single(ExtractContacts(saved!));
        Assert.Equal("Jose", form.FirstName);
        Assert.Equal("Peña", form.LastName);
        Assert.Equal("Parañaque, José Panganiban", form.PlaceOfBirth);
        Assert.Equal("Maria", contact.FirstName);
        Assert.Equal("Nuñez", contact.LastName);
    }

    [Fact]
    public async Task CreateResponse_CleansNumbers_KeepsOnesItCannotFix()
    {
        var (service, repo) = BuildService();
        EnrollmentResponse? saved = null;
        repo.Setup(r => r.AddAsync(It.IsAny<EnrollmentResponse>()))
            .Callback<EnrollmentResponse>(r => saved = r)
            .Returns(Task.CompletedTask);

        await service.CreateResponseAsync(new CreateEnrollmentResponseDto
        {
            EmailAddress = "applicant@example.com",
            Form = new ResponseFormDataDto { FirstName = "Juan", LastName = "Cruz", MobileNumber = "+63 917-123-4567", ZipCode = "60 00", ProvZipCode = "abc" },
            Contacts = [new ResponseContactDto { FirstName = "Maria", LastName = "Cruz", ContactNo = "0917 12" }],
        });

        // A number the system cannot fix is kept as typed, so the application is not lost; the Registrar fixes it.
        var form = ExtractForm(saved!)!;
        Assert.Equal("09171234567", form.MobileNumber);
        Assert.Equal("6000", form.ZipCode);
        Assert.Equal("abc", form.ProvZipCode);
        Assert.Equal("0917 12", Assert.Single(ExtractContacts(saved!)).ContactNo);
    }

    private static List<ResponseContactDto> ExtractContacts(EnrollmentResponse captured)
    {
        if (captured.Data == null) return [];
        var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        return JsonSerializer.Deserialize<ResponseDataDto>(captured.Data.RootElement.GetRawText(), opts)?.Contacts ?? [];
    }

    // ── 1. Long fields are truncated to ValidationConstants limits ────────────

    [Fact]
    public async Task Sanitize_LongFormFields_AreTruncatedToLimits()
    {
        var (svc, repoMock) = BuildService();

        EnrollmentResponse? captured = null;
        repoMock.Setup(r => r.AddAsync(It.IsAny<EnrollmentResponse>()))
                .Callback<EnrollmentResponse>(r => captured = r)
                .Returns(Task.CompletedTask);

        var longString = new string('X', 10_000);
        var dto = new CreateEnrollmentResponseDto
        {
            EmailAddress = "test@example.com",
            Form = new ResponseFormDataDto
            {
                FirstName       = longString,
                LastName        = longString,
                MiddleName      = longString,
                Suffix          = longString,
                PlaceOfBirth    = longString,
                Sex             = longString,
                MobileNumber    = longString,
                HouseStreet     = longString,
                Barangay        = longString,
                Province        = longString,
                ZipCode         = longString,
                LastSchoolAttended = longString,
                SchoolAddress   = longString,
                PreviousCollege = longString,
                PreviousCourse  = longString,
                FamilyMedicalConditionsNotes = longString,
                OngoingMedications           = longString,
            }
        };

        await svc.CreateResponseAsync(dto);

        Assert.NotNull(captured);
        var f = ExtractForm(captured);
        Assert.NotNull(f);

        Assert.Equal(ValidationConstants.NameMax,        f.FirstName.Length);
        Assert.Equal(ValidationConstants.NameMax,        f.LastName.Length);
        Assert.Equal(ValidationConstants.ShortMax,       f.MiddleName!.Length);
        Assert.Equal(ValidationConstants.ShortMax,       f.Suffix!.Length);
        Assert.Equal(ValidationConstants.AddressMax,     f.PlaceOfBirth!.Length);
        Assert.Equal(ValidationConstants.ShortMax,       f.Sex!.Length);
        Assert.Equal(ValidationConstants.PhoneMax,       f.MobileNumber!.Length);
        Assert.Equal(ValidationConstants.LongAddressMax, f.HouseStreet!.Length);
        Assert.Equal(ValidationConstants.AddressMax,     f.Barangay!.Length);
        Assert.Equal(ValidationConstants.AddressMax,     f.Province!.Length);
        Assert.Equal(ValidationConstants.ZipCodeMax,     f.ZipCode!.Length);
        Assert.Equal(ValidationConstants.LongAddressMax, f.LastSchoolAttended!.Length);
        Assert.Equal(ValidationConstants.LongAddressMax, f.SchoolAddress!.Length);
        Assert.Equal(ValidationConstants.AddressMax,     f.PreviousCollege!.Length);
        Assert.Equal(ValidationConstants.AddressMax,     f.PreviousCourse!.Length);
        Assert.Equal(ValidationConstants.NotesMax,       f.FamilyMedicalConditionsNotes!.Length);
        Assert.Equal(ValidationConstants.NotesMax,       f.OngoingMedications!.Length);
    }

    // ── 2. Nested Contacts are truncated ─────────────────────────────────────

    [Fact]
    public async Task Sanitize_LongContactFields_AreTruncated()
    {
        var (svc, repoMock) = BuildService();

        EnrollmentResponse? captured = null;
        repoMock.Setup(r => r.AddAsync(It.IsAny<EnrollmentResponse>()))
                .Callback<EnrollmentResponse>(r => captured = r)
                .Returns(Task.CompletedTask);

        var longString = new string('C', 10_000);
        var dto = new CreateEnrollmentResponseDto
        {
            EmailAddress = "test@example.com",
            Contacts = new List<ResponseContactDto>
            {
                new ResponseContactDto
                {
                    FirstName   = longString,
                    LastName    = longString,
                    ContactNo   = longString,
                    Occupation  = longString,
                    Email       = longString,
                    Workplace   = longString,
                    FacebookAccount = longString,
                    GuardianRelationshipDescription = longString,
                }
            }
        };

        await svc.CreateResponseAsync(dto);

        Assert.NotNull(captured);
        var contacts = ExtractContacts(captured);
        Assert.Single(contacts);
        var c = contacts[0];

        Assert.Equal(ValidationConstants.NameMax,    c.FirstName.Length);
        Assert.Equal(ValidationConstants.NameMax,    c.LastName.Length);
        Assert.Equal(ValidationConstants.PhoneMax,   c.ContactNo.Length);
        Assert.Equal(ValidationConstants.AddressMax, c.Occupation!.Length);
        Assert.Equal(320,                            c.Email!.Length);
        Assert.Equal(ValidationConstants.AddressMax, c.Workplace!.Length);
        Assert.Equal(ValidationConstants.NameMax,    c.FacebookAccount!.Length);
        Assert.Equal(ValidationConstants.AddressMax, c.GuardianRelationshipDescription!.Length);
    }

    // ── 3. Whitespace trimming ────────────────────────────────────────────────

    [Fact]
    public async Task Sanitize_LeadingTrailingWhitespace_IsTrimmed()
    {
        var (svc, repoMock) = BuildService();

        EnrollmentResponse? captured = null;
        repoMock.Setup(r => r.AddAsync(It.IsAny<EnrollmentResponse>()))
                .Callback<EnrollmentResponse>(r => captured = r)
                .Returns(Task.CompletedTask);

        var dto = new CreateEnrollmentResponseDto
        {
            EmailAddress = "test@example.com",
            Form = new ResponseFormDataDto
            {
                FirstName = "  Juan  ",
                LastName  = "\tDela Cruz\n",
                Sex       = " M ",
                MobileNumber = " 09123456789 ",
                Barangay  = " Labangon ",
                Province  = " Cebu ",
                ZipCode   = " 6000 ",
                LastSchoolAttended = "USC",
                SchoolAddress      = "Cebu City",
                PreviousCollege    = "USC",
                PreviousCourse     = "BS CS",
            }
        };

        await svc.CreateResponseAsync(dto);

        Assert.NotNull(captured);
        var f = ExtractForm(captured);
        Assert.NotNull(f);

        Assert.Equal("Juan", f.FirstName);
        Assert.Equal("Dela Cruz", f.LastName);
        Assert.Equal("M", f.Sex);
        Assert.Equal("09123456789", f.MobileNumber);
        Assert.Equal("Labangon", f.Barangay);
        Assert.Equal("Cebu", f.Province);
        Assert.Equal("6000", f.ZipCode);
    }

    // ── 4. Normal-length payload passes through unchanged ────────────────────

    [Fact]
    public async Task Sanitize_NormalPayload_PassesThroughUnchanged()
    {
        var (svc, repoMock) = BuildService();

        EnrollmentResponse? captured = null;
        repoMock.Setup(r => r.AddAsync(It.IsAny<EnrollmentResponse>()))
                .Callback<EnrollmentResponse>(r => captured = r)
                .Returns(Task.CompletedTask);

        var dto = new CreateEnrollmentResponseDto
        {
            EmailAddress = "maria@example.com",
            Form = new ResponseFormDataDto
            {
                FirstName    = "Maria",
                LastName     = "Santos",
                Sex          = "Female",
                Nationality  = "Filipino",
                MobileNumber = "09123456789",
                Barangay     = "Guadalupe",
                Province     = "Cebu",
                ZipCode      = "6000",
                LastSchoolAttended = "University of the Philippines",
                SchoolAddress      = "Diliman, Quezon City",
                PreviousCollege    = "UP Diliman",
                PreviousCourse     = "BS Computer Science",
            },
            Contacts = new List<ResponseContactDto>
            {
                new ResponseContactDto { FirstName = "Jose", LastName = "Santos", RelationType = 1, ContactNo = "09111111111" }
            }
        };

        await svc.CreateResponseAsync(dto);

        Assert.NotNull(captured);
        var f = ExtractForm(captured);
        Assert.NotNull(f);

        Assert.Equal("Maria", f.FirstName);
        Assert.Equal("Santos", f.LastName);
        Assert.Equal("09123456789", f.MobileNumber);
        Assert.Equal("Filipino", f.Nationality);
    }

    // ── 5. Logger captures field name and length, NOT content ────────────────

    [Fact]
    public async Task Sanitize_LongField_LogsFieldNameAndLength_NotContent()
    {
        var logMessages = new List<string>();
        var mockLogger = new Mock<ILogger<EnrollmentService>>();
        mockLogger
            .Setup(l => l.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => true),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()))
            .Callback<LogLevel, EventId, object, Exception?, Delegate>((lvl, eid, state, ex, formatter) =>
            {
                logMessages.Add(formatter.DynamicInvoke(state, ex)?.ToString() ?? "");
            });

        var (svc, repoMock) = BuildService(mockLogger.Object);
        repoMock.Setup(r => r.AddAsync(It.IsAny<EnrollmentResponse>())).Returns(Task.CompletedTask);

        const string SecretContent = "SECRET_CONTENT_THAT_SHOULD_NOT_BE_LOGGED";
        var dto = new CreateEnrollmentResponseDto
        {
            EmailAddress = "test@example.com",
            Form = new ResponseFormDataDto
            {
                FirstName    = new string('A', 5) + SecretContent + new string('B', ValidationConstants.NameMax),
                LastName     = "Short",
                MobileNumber = "09123456789",
                Barangay     = "B", Province = "P", ZipCode = "Z",
                LastSchoolAttended = "L", SchoolAddress = "S",
                PreviousCollege = "P", PreviousCourse = "P",
            }
        };

        await svc.CreateResponseAsync(dto);

        // At least one warning should have been logged for FirstName
        Assert.NotEmpty(logMessages);
        foreach (var msg in logMessages)
        {
            // Must contain "FirstName" (field name) and the actual length (number) 
            Assert.Contains("FirstName", msg);
            // Must NOT contain the secret content payload
            Assert.DoesNotContain(SecretContent, msg);
        }
    }

    // ── 6. Realistic Apps Script webhook payload returns 201 ─────────────────
    // Field names match ResponseFormDataDto / ResponseContactDto property names
    // as they appear in the current webhook output.

    [Fact]
    public async Task Sanitize_RealisticAppsScriptPayload_ProcessedSuccessfully()
    {
        var (svc, _) = BuildService();

        // This mirrors a real Apps Script POST body (camelCase field names,
        // contacts nested under form.contacts per the current webhook version).
        var payload = new CreateEnrollmentResponseDto
        {
            EmailAddress = "student@example.com",
            Form = new ResponseFormDataDto
            {
                FirstName    = "Juan",
                MiddleName   = "dela",
                LastName     = "Cruz",
                Suffix       = "",
                DateOfBirth  = "2005-08-12",
                PlaceOfBirth = "Cebu City",
                Sex          = "Male",
                CivilStatus  = "Single",
                Nationality  = "Filipino",
                Gender       = "Male",
                BloodType    = "O+",
                Religion     = "Roman Catholic",
                MobileNumber = "09123456789",
                HouseStreet  = "123 Mango Avenue",
                Barangay     = "Labangon",
                CityOfMunicipality = "Cebu City",
                Province     = "Cebu",
                ZipCode      = "6000",
                LastSchoolAttended = "Cebu Institute of Technology",
                SchoolAddress      = "N. Bacalso Ave, Cebu City",
                PreviousCollege    = "CIT University",
                PreviousCourse     = "BS Computer Engineering",
                YearLevel    = 1,
                StudentType  = 1,
                LRN          = "123456789012",
                AcademicYear = "2024-2025",
                Contacts = new List<ResponseContactDto>
                {
                    new ResponseContactDto
                    {
                        FirstName   = "Jose",
                        LastName    = "Cruz",
                        RelationType = 1,   // Father
                        Occupation  = "Engineer",
                        ContactNo   = "09111111111"
                    },
                    new ResponseContactDto
                    {
                        FirstName   = "Maria",
                        LastName    = "Cruz",
                        RelationType = 2,   // Mother
                        Occupation  = "Teacher",
                        ContactNo   = "09222222222"
                    }
                }
            }
        };

        // Should complete without throwing
        var id = await svc.CreateResponseAsync(payload);
        Assert.NotEqual(Guid.Empty, id);
    }
}

// ── DaysOfWeek regex validation tests ────────────────────────────────────────

public class DaysOfWeekValidationTests
{
    private static IList<ValidationResult> Validate(string daysOfWeek)
    {
        var dto = new CreateClassScheduleDto
        {
            ClassID    = Guid.NewGuid(),
            DaysOfWeek = daysOfWeek,
            StartTime  = new TimeOnly(8, 0),
            EndTime    = new TimeOnly(9, 0),
            Room       = "Room 101"
        };
        var ctx     = new ValidationContext(dto);
        var results = new List<ValidationResult>();
        Validator.TryValidateObject(dto, ctx, results, validateAllProperties: true);
        return results;
    }

    [Theory]
    [InlineData("MWF")]
    [InlineData("M/W/F")]
    [InlineData("M,W,F")]
    [InlineData("TTH")]
    [InlineData("M-F")]
    [InlineData("MWF TTH")]
    public void DaysOfWeek_ValidValues_PassValidation(string value)
    {
        var errors = Validate(value);
        Assert.Empty(errors);
    }

    [Theory]
    [InlineData("MWF<script>")]
    [InlineData("<script>alert(1)</script>")]
    [InlineData("MWF; DROP TABLE")]
    [InlineData("MWF123")]
    [InlineData("M@W")]
    public void DaysOfWeek_InvalidValues_FailValidation(string value)
    {
        var errors = Validate(value);
        Assert.NotEmpty(errors);
    }
}
