using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.DTOs.Enrollment;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Applying to DBTC with no account — the only thing a stranger can write to, so the checks that
/// hold it shut matter more than the happy path.
/// </summary>
public class PublicEnrollmentTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly PublicEnrollmentService _service;
    private readonly Mock<IEnrollmentService> _enrollment = new();
    private readonly List<CreateEnrollmentResponseDto> _recorded = new();
    private readonly Guid _responseId = Guid.Parse("3f2a9c14-0000-4000-8000-000000000001");

    private readonly AcademicTerm _open = new()
    {
        TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 2,
        EnrollmentOpensOn = new DateOnly(2026, 11, 17), EnrollmentClosesOn = new DateOnly(2026, 11, 28),
    };
    private readonly AcademicTerm _closed = new()
    {
        TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1,
    };

    private static readonly DateOnly WhileOpen = new(2026, 11, 20);
    private static readonly DateOnly AfterClosing = new(2026, 12, 1);

    public PublicEnrollmentTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);

        _context.AcademicTerms.AddRange(_open, _closed);
        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSIT", ProgramName = "BS Information Technology" },
            new AcademicProgram { ProgramID = 1, ProgramCode = "BSCS", ProgramName = "BS Computer Science" });
        _context.SaveChanges();

        _enrollment
            .Setup(e => e.CreateResponseAsync(It.IsAny<CreateEnrollmentResponseDto>()))
            .ReturnsAsync((CreateEnrollmentResponseDto dto) =>
            {
                _recorded.Add(dto);
                return _responseId;
            });

        _service = new PublicEnrollmentService(_context, _enrollment.Object);
    }

    public void Dispose() => _context.Dispose();

    /// <summary>A form good enough to be accepted, for a test to spoil one field at a time.</summary>
    private static CreateEnrollmentResponseDto Application(
        int studentType = 1, string email = "applicant@example.com",
        string first = "Ana", string last = "Cruz", string? course = "BSIT")
        => new()
        {
            EmailAddress = email,
            Form = new ResponseFormDataDto
            {
                FirstName = first,
                LastName = last,
                StudentType = studentType,
                IncomingCourse = course,
                MobileNumber = "09171234567",
                DateOfBirth = "2005-03-14",
                YearGraduated = "2024",
            }
        };

    // ── Is anyone allowed in today ───────────────────────────────────────────

    [Fact]
    public async Task Status_IsClosedWhenNoTermIsOpen_AndNamesNoCourses()
    {
        var status = await _service.GetStatusAsync(AfterClosing);

        Assert.False(status.IsOpen);
        Assert.Null(status.TermLabel);
        Assert.Null(status.ClosesOn);
        Assert.Empty(status.Programs);
    }

    [Fact]
    public async Task Status_WhileOpen_SaysWhichTermAndUntilWhen_AndListsCourses()
    {
        var status = await _service.GetStatusAsync(WhileOpen);

        Assert.True(status.IsOpen);
        Assert.Equal("2026-2027 (2nd Sem)", status.TermLabel);
        Assert.Equal(new DateOnly(2026, 11, 28), status.ClosesOn);
        Assert.Equal(new[] { "BSCS", "BSIT" }, status.Programs.Select(p => p.ProgramCode));
    }

    // ── The window is the gate ───────────────────────────────────────────────

    [Fact]
    public async Task Submit_OutsideTheEnrollmentWindow_IsRefusedAndRecordsNothing()
    {
        var refused = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.SubmitAsync(Application(), AfterClosing));

        Assert.Contains("closed right now", refused.Message);
        Assert.Empty(_recorded);
        _enrollment.Verify(e => e.CreateResponseAsync(It.IsAny<CreateEnrollmentResponseDto>()), Times.Never);
    }

    [Fact]
    public async Task Submit_OnTheDayEnrollmentOpens_AndOnTheDayItCloses_IsAccepted()
    {
        await _service.SubmitAsync(Application(), new DateOnly(2026, 11, 17));
        await _service.SubmitAsync(Application(), new DateOnly(2026, 11, 28));

        Assert.Equal(2, _recorded.Count);
    }

    // ── What an applicant may claim to be ────────────────────────────────────

    [Fact]
    public async Task Submit_AsANewStudent_RecordsAnUnprocessedResponseAndReturnsAReference()
    {
        var receipt = await _service.SubmitAsync(Application(), WhileOpen);

        Assert.Equal(_responseId, receipt.ResponseId);
        Assert.Equal("3F2A9C14", receipt.Reference);
        Assert.Equal("2026-2027 (2nd Sem)", receipt.TermLabel);

        var sent = Assert.Single(_recorded);
        Assert.Equal("applicant@example.com", sent.EmailAddress);
        Assert.Equal(1, sent.Form!.StudentType);
        Assert.Equal(1, sent.Form.YearLevel);
    }

    [Fact]
    public async Task Submit_AsATransferee_LeavesTheYearLevelForTheRegistrar()
    {
        await _service.SubmitAsync(Application(studentType: 3), WhileOpen);

        var sent = Assert.Single(_recorded);
        Assert.Equal(3, sent.Form!.StudentType);
        // The Registrar sets it once they know which credits are granted.
        Assert.Null(sent.Form.YearLevel);
    }

    [Theory]
    [InlineData(2)]   // an old student: they enrol in the Student Portal, signed in
    [InlineData(0)]
    [InlineData(99)]
    public async Task Submit_AsAnythingButANewStudentOrTransferee_IsRefused(int studentType)
    {
        var refused = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.SubmitAsync(Application(studentType: studentType), WhileOpen));

        Assert.Contains("Student Portal", refused.Message);
        Assert.Empty(_recorded);
    }

    [Fact]
    public async Task Submit_WithNoStudentTypeAtAll_IsRefused()
    {
        var dto = Application();
        dto.Form!.StudentType = null;

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitAsync(dto, WhileOpen));
        Assert.Empty(_recorded);
    }

    // ── What the applicant does not get to decide ────────────────────────────

    [Fact]
    public async Task Submit_DropsAPreviousCollegeFromSomeoneEnrollingAsAFirstYear()
    {
        var dto = Application(studentType: 1);
        dto.Form!.PreviousCollege = "Some University";
        dto.Form.PreviousCourse = "BS Information Technology";
        dto.Form.PreviousStudentID = "2019-00123";

        await _service.SubmitAsync(dto, WhileOpen);

        var sent = Assert.Single(_recorded).Form!;
        Assert.Null(sent.PreviousCollege);
        Assert.Null(sent.PreviousCourse);
        Assert.Null(sent.PreviousStudentID);
    }

    [Fact]
    public async Task Submit_KeepsAPreviousCollegeFromATransferee()
    {
        var dto = Application(studentType: 3);
        dto.Form!.PreviousCollege = "Some University";
        dto.Form.PreviousStudentID = "2019-00123";

        await _service.SubmitAsync(dto, WhileOpen);

        var sent = Assert.Single(_recorded).Form!;
        Assert.Equal("Some University", sent.PreviousCollege);
        Assert.Equal("2019-00123", sent.PreviousStudentID);
    }

    [Fact]
    public async Task Submit_TakesTheTermFromTheServer_WhateverTheApplicantSent()
    {
        var dto = Application();
        dto.Form!.AcademicYear = "2019-2020";
        dto.Form.YearLevel = 4;

        await _service.SubmitAsync(dto, WhileOpen);

        var sent = Assert.Single(_recorded);
        Assert.Equal("2026-2027", sent.Form!.AcademicYear);
        Assert.Equal(1, sent.Form.YearLevel);
    }

    // ── Enough to be worth a Registrar's time ────────────────────────────────

    [Theory]
    [InlineData("", "Ana", "Cruz", "BSIT")]
    [InlineData("not-an-email", "Ana", "Cruz", "BSIT")]
    [InlineData("applicant@example.com", "", "Cruz", "BSIT")]
    [InlineData("applicant@example.com", "Ana", "   ", "BSIT")]
    [InlineData("applicant@example.com", "Ana", "Cruz", "")]
    public async Task Submit_WithoutTheDetailsTheRegistrarNeeds_IsRefused(
        string email, string first, string last, string course)
    {
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.SubmitAsync(Application(email: email, first: first, last: last, course: course), WhileOpen));

        Assert.Empty(_recorded);
    }

    [Fact]
    public async Task Submit_TrimsAndLowerCasesTheEmailAddress()
    {
        // The Excel importer lower-cases the Google Form's address column, so this matches it --
        // and the duplicate check compares lower-cased, so the same person submitting twice with
        // a capital letter the second time is still the same person.
        await _service.SubmitAsync(Application(email: "  Applicant@Example.COM  "), WhileOpen);

        Assert.Equal("applicant@example.com", Assert.Single(_recorded).EmailAddress);
    }

    [Theory]
    [InlineData("@example.com")]        // nobody in front of the @
    [InlineData("applicant@")]          // nowhere to send it
    [InlineData("applicant@example")]   // no dot, so not a domain
    [InlineData("appl icant@example.com")]
    [InlineData("applicant@exa mple.com")]
    [InlineData("two@at@example.com")]
    [InlineData("applicant@.com")]
    [InlineData("applicant@example.")]
    public async Task Submit_RefusesAnAddressTheRegistrarCouldNotReply_To(string email)
    {
        var refused = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.SubmitAsync(Application(email: email), WhileOpen));

        Assert.Contains("email address", refused.Message);
        Assert.Empty(_recorded);
    }

    [Theory]
    [InlineData("applicant@example.com")]
    [InlineData("first.last+tag@mail.example.co.uk")]
    [InlineData("a@b.ph")]
    public async Task Submit_AcceptsOrdinaryAddresses(string email)
    {
        await _service.SubmitAsync(Application(email: email), WhileOpen);

        Assert.Equal(email, Assert.Single(_recorded).EmailAddress);
    }

    // ── Dates the Registrar can actually save ────────────────────────────────

    [Fact]
    public async Task Submit_RewritesTheDatesTheApplicantGave_AsPlainIsoDates()
    {
        var dto = Application();
        dto.Form!.DateOfBirth = "March 14, 2005";
        dto.Form.YearGraduated = "2024";   // a bare year, as the Google Form's column holds

        await _service.SubmitAsync(dto, WhileOpen);

        var sent = Assert.Single(_recorded).Form!;
        Assert.Equal("2005-03-14", sent.DateOfBirth);
        Assert.Equal("2024-01-01", sent.YearGraduated);
    }

    [Theory]
    [InlineData("not a date at all")]
    [InlineData("dunno")]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    [InlineData("32/13/2005")]
    public async Task Submit_RefusesABirthdayTheRegistrarsFormWouldReject(string? birthday)
    {
        // EnrollmentFormDto.DateOfBirth is a non-nullable DateOnly, so a blank or unreadable date
        // reaches the Registrar as a response they cannot save without retyping it.
        var dto = Application();
        dto.Form!.DateOfBirth = birthday;

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitAsync(dto, WhileOpen));
        Assert.Empty(_recorded);
    }

    [Fact]
    public async Task Submit_RefusesAnUnreadableYearOfLastSchool()
    {
        var dto = Application();
        dto.Form!.YearGraduated = "ages ago";

        var refused = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.SubmitAsync(dto, WhileOpen));

        Assert.Contains("last school", refused.Message);
    }

    [Fact]
    public async Task Submit_AcceptsAContactWithNoBirthday_ButNotAnUnreadableOne()
    {
        var withoutOne = Application();
        withoutOne.Contacts.Add(new ResponseContactDto
        {
            FirstName = "Pedro", LastName = "Cruz", RelationType = 1, ContactNo = "09170000001"
        });
        await _service.SubmitAsync(withoutOne, WhileOpen);
        Assert.Single(_recorded);

        var withNonsense = Application();
        withNonsense.Contacts.Add(new ResponseContactDto
        {
            FirstName = "Maria", LastName = "Cruz", RelationType = 2, ContactNo = "09170000002",
            DateOfBirth = "yesterday"
        });
        var refused = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.SubmitAsync(withNonsense, WhileOpen));
        Assert.Contains("Maria Cruz", refused.Message);
    }

    [Fact]
    public async Task Submit_RewritesAContactsBirthday_AsAPlainIsoDate()
    {
        var dto = Application();
        dto.Contacts.Add(new ResponseContactDto
        {
            FirstName = "Pedro", LastName = "Cruz", RelationType = 1, ContactNo = "09170000001",
            DateOfBirth = "April 2, 1980"
        });

        await _service.SubmitAsync(dto, WhileOpen);

        Assert.Equal("1980-04-02", Assert.Single(_recorded).Contacts.Single().DateOfBirth);
    }

    [Fact]
    public async Task Submit_WithNoFormAtAll_IsRefused()
    {
        var dto = new CreateEnrollmentResponseDto { EmailAddress = "applicant@example.com", Form = null };

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitAsync(dto, WhileOpen));
        Assert.Empty(_recorded);
    }

    // ── The same questions the Google Form asked ─────────────────────────────

    /// <summary>
    /// The public form replaces the Google Form, so it has to collect what the Google Form
    /// collected. These are the fields the webhook contract carries that an applicant fills in
    /// themselves -- everything else on it is set by the server or by the Registrar later. If a
    /// field is added to the intake contract, it belongs in the public page too, and this is
    /// where that gets noticed.
    /// </summary>
    public static readonly string[] AskedOfTheApplicant =
    {
        "FirstName", "MiddleName", "LastName", "Suffix", "DateOfBirth", "PlaceOfBirth", "Sex",
        "CivilStatus", "Nationality", "Gender", "BloodType", "Religion", "FacebookName",
        "MobileNumber", "HouseStreet", "Barangay", "CityOfMunicipality", "Province", "ZipCode",
        "ProvHouseStreet", "ProvBarangay", "ProvCityMunicipality", "ProvProvince", "ProvZipCode",
        "LastSchoolAttended", "SchoolAddress", "ProgramTrackStrand", "YearGraduated",
        "PreviousCollege", "PreviousCourse", "PreviousStudentID", "StudentType", "LRN",
        "IncomingCourse", "BirthOrder", "NumberOfSiblings", "FamilyStatus",
        "PresentMedicalConditions", "PastMedicalHistory", "ImmunizationHistory",
        "FamilyMedicalConditionsNotes", "OngoingMedications", "DevelopmentalConditions",
        "OtherMedicalDiagnosis",
    };

    [Fact]
    public void EveryFieldTheApplicantFillsIn_IsOnTheIntakeContract()
    {
        var onContract = typeof(ResponseFormDataDto).GetProperties().Select(p => p.Name).ToHashSet();

        Assert.All(AskedOfTheApplicant, name => Assert.Contains(name, onContract));
    }

    [Fact]
    public void TheIntakeContract_HasNothingTheApplicantIsNeverAsked_ExceptWhatTheServerSets()
    {
        // Age and AcademicYear and YearLevel are worked out here; CityMunicipality is an older
        // second name for CityOfMunicipality; IntendedProgramCode is read nowhere at all;
        // Contacts are their own list. Everything else must be asked.
        var setByUsOrUnused = new[]
        {
            "Age", "AcademicYear", "YearLevel", "CityMunicipality", "IntendedProgramCode", "Contacts"
        };

        var unaccounted = typeof(ResponseFormDataDto).GetProperties()
            .Select(p => p.Name)
            .Where(name => !AskedOfTheApplicant.Contains(name) && !setByUsOrUnused.Contains(name))
            .ToList();

        Assert.Empty(unaccounted);
    }

    /// <summary>
    /// What the Google Form asked of each parent and guardian, as the Excel importer still reads
    /// it. ContactName, Relationship and ContactNumber are left out on purpose: they are
    /// write-only fallbacks that older webhook payloads used, and they land in the fields above.
    /// </summary>
    public static readonly string[] AskedOfEachContact =
    {
        "FirstName", "LastName", "Occupation", "ContactNo", "Email", "DateOfBirth", "Workplace",
        "FacebookAccount", "LivingWithGuardian", "GuardianRelationshipDescription",
    };

    [Fact]
    public void EveryContactFieldTheApplicantFillsIn_IsOnTheIntakeContract()
    {
        var onContract = typeof(ResponseContactDto).GetProperties().Select(p => p.Name).ToHashSet();

        Assert.All(AskedOfEachContact, name => Assert.Contains(name, onContract));
    }

    [Fact]
    public void TheContactContract_HasNothingTheApplicantIsNeverAsked_ExceptTheOldAliases()
    {
        // RelationType is which card they filled in, not something they type.
        var setByUsOrLegacy = new[] { "RelationType", "ContactName", "Relationship", "ContactNumber" };

        var unaccounted = typeof(ResponseContactDto).GetProperties()
            .Select(p => p.Name)
            .Where(name => !AskedOfEachContact.Contains(name) && !setByUsOrLegacy.Contains(name))
            .ToList();

        Assert.Empty(unaccounted);
    }

    [Fact]
    public async Task Submit_KeepsATransfereesOwnYearLevel_ButPinsANewStudentToYearOne()
    {
        var transferee = Application(studentType: 3);
        transferee.Form!.YearLevel = 3;
        await _service.SubmitAsync(transferee, WhileOpen);
        Assert.Equal(3, _recorded[0].Form!.YearLevel);

        var newStudent = Application();
        newStudent.Form!.YearLevel = 4;
        await _service.SubmitAsync(newStudent, WhileOpen);
        Assert.Equal(1, _recorded[1].Form!.YearLevel);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(5)]
    [InlineData(-1)]
    public async Task Submit_IgnoresAYearLevelThatIsNotOne_OfTheFour(int claimed)
    {
        var transferee = Application(studentType: 3);
        transferee.Form!.YearLevel = claimed;

        await _service.SubmitAsync(transferee, WhileOpen);

        Assert.Null(Assert.Single(_recorded).Form!.YearLevel);
    }

    [Fact]
    public async Task Submit_WorksOutTheApplicantsAgeFromTheirBirthday()
    {
        var dto = Application();
        dto.Form!.DateOfBirth = "2005-11-25";
        dto.Form.Age = 99; // whatever they claim is replaced

        await _service.SubmitAsync(dto, new DateOnly(2026, 11, 24));

        // The day before their birthday, so still 20.
        Assert.Equal(20, Assert.Single(_recorded).Form!.Age);
    }

    [Fact]
    public async Task Submit_LeavesTheAgeUnsetWhenTheBirthdayIsInTheFuture()
    {
        // A readable date, so it is kept and the Registrar can see and correct it -- but no age is
        // invented from it. A missing birthday is refused outright, which is tested separately.
        var notYetBorn = Application();
        notYetBorn.Form!.DateOfBirth = "2030-01-01";

        await _service.SubmitAsync(notYetBorn, WhileOpen);

        Assert.Null(Assert.Single(_recorded).Form!.Age);
    }

    // ── The controller, where the database is told who is asking ─────────────

    private PublicEnrollmentController Controller(out DefaultHttpContext http)
    {
        http = new DefaultHttpContext();
        return new PublicEnrollmentController(_service)
        {
            ControllerContext = new ControllerContext { HttpContext = http }
        };
    }

    [Fact]
    public async Task Controller_AsksAsAPublicApplicant_NotAsNobody()
    {
        var controller = Controller(out var http);

        await controller.GetStatus();

        // Role 0 reads nothing under row-level security, not even which term is open.
        Assert.Equal(RoleUtils.PublicApplicant, http.Items["role"]);
        Assert.Equal(-2, RoleUtils.PublicApplicant);
        Assert.False(RoleUtils.IsValidRole(RoleUtils.PublicApplicant));
    }

    [Fact]
    public async Task Controller_PublishesTheRoleEvenWhenTheSubmissionIsRejected()
    {
        var controller = Controller(out var http);

        var result = await controller.Submit(Application(studentType: 2));

        Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(RoleUtils.PublicApplicant, http.Items["role"]);
    }

    [Fact]
    public async Task Controller_NeverCarriesASignedInIdentity()
    {
        var controller = Controller(out var http);

        await controller.Submit(Application());

        // Nothing identifies a person: no user id, so nothing can be attributed to one.
        Assert.False(http.Items.ContainsKey("user_id"));
        Assert.False(http.Items.ContainsKey("firebase_uid"));
    }

    [Fact]
    public async Task Controller_ReturnsTheReferenceTheApplicantIsShown()
    {
        var controller = Controller(out _);

        var ok = Assert.IsType<OkObjectResult>(await controller.Submit(Application()));
        var receipt = Assert.IsType<PublicEnrollmentReceiptDto>(ok.Value);

        Assert.Equal("3F2A9C14", receipt.Reference);
        Assert.Equal("2026-2027 (2nd Sem)", receipt.TermLabel);
    }

    [Fact]
    public async Task Controller_ReportsWhyASubmissionWasRefused()
    {
        var controller = Controller(out _);
        var dto = Application();
        dto.Form!.IncomingCourse = null;

        var bad = Assert.IsType<BadRequestObjectResult>(await controller.Submit(dto));

        Assert.Contains("course", bad.Value!.ToString(), StringComparison.OrdinalIgnoreCase);
    }
}
