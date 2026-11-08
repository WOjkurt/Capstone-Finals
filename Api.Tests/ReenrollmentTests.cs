using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.Enrollment;
using Api.DTOs.Reenrollment;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Api.Tests;

/// <summary>Old students enrolling again from the Student Portal, including attempts to cheat the checks.</summary>
public class ReenrollmentTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly ReenrollmentService _service;
    private readonly Guid _ana = Guid.NewGuid();
    private readonly Guid _ben = Guid.NewGuid();
    private readonly Guid _registrar = Guid.NewGuid();
    private readonly AcademicTerm _first = new() { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 1 };
    private readonly AcademicTerm _second = new()
    {
        TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 2,
        EnrollmentOpensOn = new DateOnly(2026, 11, 17), EnrollmentClosesOn = new DateOnly(2026, 11, 28),
    };
    private static readonly DateOnly Open = new(2026, 11, 20);

    public ReenrollmentTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _service = new ReenrollmentService(_context);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS Information Technology" });
        _context.AcademicTerms.AddRange(_first, _second);
        _context.Users.Add(new User { UserID = _registrar, FirebaseUID = "fb-r", Email = "r@x.com", Role = RoleUtils.Registrar, IsActive = true });
        var subject = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT 101", SubjectTitle = "Intro", LecUnits = 3, ProgramID = 1, YearLevel = 1, DefaultSemester = 1 };
        _context.Subjects.Add(subject);
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = subject.SubjectID, TermID = _first.TermID, ClassName = "BSIT 1A" };
        _context.Classes.Add(cls);

        AddStudent(_ana, "Ana", "09171111111", cls.ClassID);
        AddStudent(_ben, "Ben", "09172222222", cls.ClassID);
        _context.SaveChanges();
    }

    private void AddStudent(Guid id, string first, string mobile, Guid classId)
    {
        _context.Users.Add(new User { UserID = id, FirebaseUID = "fb" + id, Email = first.ToLower() + "@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = id, Firstname = first, Lastname = "Cruz", ProgramID = 1, YearLevel = 1, LRN = "123456789012" });
        var response = new EnrollmentResponse { ResponseID = Guid.NewGuid(), Timestamp = DateTime.UtcNow.AddMonths(-5), EmailAddress = first + "@gmail.com", IsProcessed = true };
        var app = new EnrollmentApplication
        {
            ApplicationID = Guid.NewGuid(), ResponseID = response.ResponseID, ProgramID = 1, TermID = _first.TermID,
            Status = EnrollmentApplicationStatus.Active, StudentUserID = id, CreatedAt = DateTime.UtcNow.AddMonths(-5),
        };
        var form = new EnrollmentForm
        {
            EnrollmentID = Guid.NewGuid(), ApplicationID = app.ApplicationID,
            FirstName = first, MiddleName = "Santos", LastName = "Cruz", Suffix = "N/A",
            DateOfBirth = new DateOnly(2006, 3, 14), PlaceOfBirth = "Cebu City", Sex = "Female", CivilStatus = "Single",
            Nationality = "Filipino", MobileNumber = mobile, Barangay = "Pardo", CityMunicipality = "Cebu City",
            Province = "Cebu", ZipCode = "6000", LastSchoolAttended = "Abellana NHS", SchoolAddress = "Cebu City",
            YearGraduated = new DateOnly(2025, 3, 1), PreviousCollege = "N/A", PreviousCourse = "N/A", YearLevel = 1,
            LRN = "123456789012",
        };
        _context.EnrollmentResponses.Add(response);
        _context.EnrollmentApplications.Add(app);
        _context.EnrollmentForms.Add(form);
        _context.Contacts.Add(new Contact { ContactID = Guid.NewGuid(), EnrollmentID = form.EnrollmentID, FirstName = "Pedro", LastName = "Cruz", RelationType = 1, ContactNo = "09170000001" });
        _context.Contacts.Add(new Contact { ContactID = Guid.NewGuid(), EnrollmentID = form.EnrollmentID, FirstName = "Maria", LastName = "Cruz", RelationType = 2, ContactNo = "09170000002" });
        _context.StudyLoads.Add(new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = id, ClassID = classId, LoadStatus = StudyLoadStatus.Enrolled, CreatedAt = DateTime.UtcNow });
        _context.GradeClearances.Add(new GradeClearance { ClearanceID = Guid.NewGuid(), UserID = id, TermID = _first.TermID, IsCleared = true });
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private async Task<SubmitReenrollmentDto> ReadyToSend(Guid student)
    {
        var status = await _service.GetStatusAsync(student, Open);
        Assert.Equal(ReenrollmentStates.Ready, status.State);
        return new SubmitReenrollmentDto
        {
            TermId = status.TermId!.Value, YearLevel = 1, Form = status.Form!, Contacts = status.Contacts, Confirmed = true,
        };
    }

    // ── When the screens appear ──────────────────────────────────────────────

    [Fact]
    public async Task OutsideTheDates_IsClosed()
    {
        Assert.Equal(ReenrollmentStates.Closed, (await _service.GetStatusAsync(_ana, new DateOnly(2026, 11, 16))).State);
        Assert.Equal(ReenrollmentStates.Closed, (await _service.GetStatusAsync(_ana, new DateOnly(2026, 11, 29))).State);
    }

    [Fact]
    public async Task OpenAndCleared_IsReady_WithLastFormFilledIn()
    {
        var status = await _service.GetStatusAsync(_ana, Open);

        Assert.Equal(ReenrollmentStates.Ready, status.State);
        Assert.Equal("2026-2027 (2nd Sem)", status.TermLabel);
        Assert.Equal("Ana", status.Form!.FirstName);
        Assert.Equal("09171111111", status.Form.MobileNumber);
        Assert.Equal(new[] { 1, 2 }, status.YearLevelChoices);
        Assert.Equal(new[] { 1, 2 }, status.Contacts.Select(c => c.RelationType));
        Assert.Equal("2026-2027 (1st Sem)", status.FilledFromTerm);
        Assert.Contains("LastName", status.LockedFields);
    }

    [Fact]
    public async Task NotCleared_OrOnHold_IsBlockedWithReasons()
    {
        _context.GradeClearances.Single(c => c.UserID == _ana).IsCleared = false;
        _context.EnrollmentHolds.Add(new EnrollmentHold { HoldID = Guid.NewGuid(), UserID = _ana, Reason = EnrollmentHoldReasons.UnpaidBalance, Note = "P2,500", AddedByUserID = _registrar, AddedAt = DateTime.UtcNow });
        await _context.SaveChangesAsync();

        var status = await _service.GetStatusAsync(_ana, Open);

        Assert.Equal(ReenrollmentStates.OnHold, status.State);
        Assert.Contains("You are not yet cleared for 2026-2027 (1st Sem).", status.Reasons);
        Assert.Contains("You have a hold: Unpaid balance.", status.Reasons);
        Assert.DoesNotContain(status.Reasons, r => r.Contains("P2,500")); // the Registrar's note stays private
        Assert.Null(status.Form);

        var dto = new SubmitReenrollmentDto { TermId = _second.TermID, YearLevel = 1, Form = new EnrollmentFormDto { FirstName = "Ana", MiddleName = "", LastName = "Cruz", Suffix = "", PlaceOfBirth = "", Sex = "", CivilStatus = "", Nationality = "", MobileNumber = "", Barangay = "", Province = "", ZipCode = "", LastSchoolAttended = "", SchoolAddress = "", PreviousCollege = "", PreviousCourse = "" }, Confirmed = true };
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitAsync(_ana, dto, Open));
    }

    [Fact]
    public async Task RemovedHold_NoLongerBlocks()
    {
        _context.EnrollmentHolds.Add(new EnrollmentHold { HoldID = Guid.NewGuid(), UserID = _ana, Reason = EnrollmentHoldReasons.UnpaidBalance, AddedByUserID = _registrar, AddedAt = DateTime.UtcNow, RemovedAt = DateTime.UtcNow, RemovedByUserID = _registrar });
        await _context.SaveChangesAsync();
        Assert.Equal(ReenrollmentStates.Ready, (await _service.GetStatusAsync(_ana, Open)).State);
    }

    [Fact]
    public async Task NoFormOnFile_OrNoEarlierTerm_SendsToRegistrar()
    {
        _context.StudyLoads.RemoveRange(_context.StudyLoads.Where(s => s.UserID == _ana));
        await _context.SaveChangesAsync();
        var status = await _service.GetStatusAsync(_ana, Open);
        Assert.Equal(ReenrollmentStates.NotEligible, status.State);
        Assert.Contains("earlier term", status.Reasons[0]);
    }

    [Fact]
    public async Task StaffAccount_HasNoStudentRecord()
    {
        var status = await _service.GetStatusAsync(_registrar, Open);
        Assert.Equal(ReenrollmentStates.NotEligible, status.State);
        Assert.Null(status.Form);
    }

    // ── Sending ──────────────────────────────────────────────────────────────

    [Fact]
    public async Task Submit_CreatesPendingReturningApplication_WithChangedFields()
    {
        var dto = await ReadyToSend(_ana);
        dto.Form.MobileNumber = "09189999999";
        dto.Form.Barangay = "Inayawan";
        dto.Contacts[0].ContactNo = "09170000099"; // father's new number
        dto.YearLevel = 2;

        var (id, term, changed) = await _service.SubmitAsync(_ana, dto, Open);

        Assert.Equal("2026-2027 (2nd Sem)", term);
        Assert.Equal(new[] { "Mobile Number", "Barangay", "Father" }, changed);
        var app = await _context.EnrollmentApplications.SingleAsync(a => a.ApplicationID == id);
        Assert.True(app.IsReturning);
        Assert.Equal(EnrollmentApplicationStatus.Pending, app.Status);
        Assert.Equal(_ana, app.StudentUserID);
        Assert.Equal(_second.TermID, app.TermID);
        Assert.Equal(1, app.ProgramID);
        Assert.Equal("Mobile Number, Barangay, Father", app.ChangedFields);
        Assert.True((await _context.EnrollmentResponses.SingleAsync(r => r.ResponseID == app.ResponseID)).IsProcessed);
        var form = await _context.EnrollmentForms.SingleAsync(f => f.ApplicationID == id);
        Assert.Equal(("09189999999", "Inayawan", 2, 2), (form.MobileNumber, form.Barangay, form.YearLevel, form.StudentType));
        Assert.Equal(2, await _context.Contacts.CountAsync(c => c.EnrollmentID == form.EnrollmentID));

        var after = await _service.GetStatusAsync(_ana, Open);
        Assert.Equal(ReenrollmentStates.Submitted, after.State);
        Assert.Equal("Pending", after.ApplicationStatus);
    }

    [Fact]
    public async Task NothingChanged_IsFine()
    {
        var (_, _, changed) = await _service.SubmitAsync(_ana, await ReadyToSend(_ana), Open);
        Assert.Empty(changed);
    }

    [Fact]
    public async Task LockedFields_AreTakenFromTheRecord_WhateverIsSent()
    {
        var dto = await ReadyToSend(_ana);
        dto.Form.FirstName = "Hacker";
        dto.Form.LastName = "Mendoza";
        dto.Form.DateOfBirth = new DateOnly(1990, 1, 1);
        dto.Form.Sex = "Male";
        dto.Form.LRN = "999999999999";
        dto.Form.LastSchoolAttended = "Harvard";

        var (id, _, changed) = await _service.SubmitAsync(_ana, dto, Open);

        var form = await _context.EnrollmentForms.SingleAsync(f => f.ApplicationID == id);
        Assert.Equal(("Ana", "Cruz", new DateOnly(2006, 3, 14), "Female", "123456789012", "Abellana NHS"),
            (form.FirstName, form.LastName, form.DateOfBirth, form.Sex, form.LRN, form.LastSchoolAttended));
        Assert.Empty(changed);
    }

    [Fact]
    public async Task SecondSubmit_IsRefused()
    {
        await _service.SubmitAsync(_ana, await ReadyToSend(_ana), Open);
        var again = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.SubmitAsync(_ana, new SubmitReenrollmentDto { TermId = _second.TermID, YearLevel = 1, Form = new EnrollmentFormDto { FirstName = "Ana", MiddleName = "", LastName = "Cruz", Suffix = "", PlaceOfBirth = "", Sex = "", CivilStatus = "", Nationality = "", MobileNumber = "", Barangay = "", Province = "", ZipCode = "", LastSchoolAttended = "", SchoolAddress = "", PreviousCollege = "", PreviousCourse = "" }, Confirmed = true }, Open));
        Assert.Contains("already sent", again.Message);
        Assert.Equal(1, await _context.EnrollmentApplications.CountAsync(a => a.StudentUserID == _ana && a.TermID == _second.TermID));
    }

    [Fact]
    public async Task AfterRejection_TheStudentCanSendAgain()
    {
        var (id, _, _) = await _service.SubmitAsync(_ana, await ReadyToSend(_ana), Open);
        (await _context.EnrollmentApplications.SingleAsync(a => a.ApplicationID == id)).Status = EnrollmentApplicationStatus.Rejected;
        await _context.SaveChangesAsync();

        Assert.Equal(ReenrollmentStates.Ready, (await _service.GetStatusAsync(_ana, Open)).State);
    }

    [Fact]
    public async Task WrongTerm_NotConfirmed_OrYearLevelTooHigh_AreRefused()
    {
        var dto = await ReadyToSend(_ana);
        dto.TermId = _first.TermID;
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitAsync(_ana, dto, Open));

        dto = await ReadyToSend(_ana);
        dto.Confirmed = false;
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitAsync(_ana, dto, Open));

        dto = await ReadyToSend(_ana);
        dto.YearLevel = 4;
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitAsync(_ana, dto, Open));

        dto = await ReadyToSend(_ana);
        dto.Contacts.Add(new ContactDto { FirstName = "X", LastName = "Y", RelationType = 1, ContactNo = "09170000003" });
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitAsync(_ana, dto, Open));

        Assert.Equal(0, await _context.EnrollmentApplications.CountAsync(a => a.TermID == _second.TermID));
    }

    // ── Other students' data ─────────────────────────────────────────────────

    [Fact]
    public async Task EachStudentOnlyEverSeesTheirOwnForm()
    {
        var ana = await _service.GetStatusAsync(_ana, Open);
        var ben = await _service.GetStatusAsync(_ben, Open);
        Assert.Equal("09171111111", ana.Form!.MobileNumber);
        Assert.Equal("09172222222", ben.Form!.MobileNumber);
    }

    [Fact]
    public async Task SendingSomeoneElsesFormData_StillSavesUnderTheSignedInStudent()
    {
        var benForm = (await _service.GetStatusAsync(_ben, Open)).Form!;
        var dto = await ReadyToSend(_ana);
        dto.Form = benForm; // Ana pastes Ben's data

        var (id, _, _) = await _service.SubmitAsync(_ana, dto, Open);

        var app = await _context.EnrollmentApplications.SingleAsync(a => a.ApplicationID == id);
        Assert.Equal(_ana, app.StudentUserID);
        var form = await _context.EnrollmentForms.SingleAsync(f => f.ApplicationID == id);
        Assert.Equal("Ana", form.FirstName); // locked fields come from Ana's record
        Assert.Equal(0, await _context.EnrollmentApplications.CountAsync(a => a.StudentUserID == _ben && a.TermID == _second.TermID));
    }

    [Fact]
    public void TheRequestHasNoStudentIdToSwap()
    {
        Assert.DoesNotContain(typeof(SubmitReenrollmentDto).GetProperties(),
            p => p.Name.Contains("User", StringComparison.OrdinalIgnoreCase) || p.Name.Contains("Student", StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(typeof(ReenrollmentController).GetMethods().SelectMany(m => m.GetParameters()), p => p.ParameterType == typeof(Guid));
    }

    [Fact]
    public void OnlyStudents_CanUseTheEndpoints() =>
        Assert.NotEmpty(typeof(ReenrollmentController).GetCustomAttributes(typeof(RequireStudentAttribute), false));

    [Fact]
    public async Task Controller_UsesTheSignedInStudent()
    {
        var controller = new ReenrollmentController(_service)
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
        };
        Assert.IsType<UnauthorizedObjectResult>(await controller.GetStatus());

        controller.HttpContext.Items["user_id"] = _ben;
        var ok = Assert.IsType<OkObjectResult>(await controller.GetStatus());
        var status = Assert.IsType<ReenrollmentStatusDto>(ok.Value);
        Assert.True(status.Form == null || status.Form.FirstName == "Ben");
    }

    // ── The Registrar approves ───────────────────────────────────────────────

    [Fact]
    public async Task Approving_GoesStraightToActive_AndSetsYearLevel()
    {
        var dto = await ReadyToSend(_ana);
        dto.YearLevel = 2;
        var (id, _, _) = await _service.SubmitAsync(_ana, dto, Open);

        var enrollment = new EnrollmentService(_context, new EnrollmentResponseRepository(_context),
            new EnrollmentApplicationRepository(_context), new EnrollmentFormRepository(_context),
            new ContactRepository(_context), new UserDetailsRepository(_context), new UserRepository(_context),
            NullLogger<EnrollmentService>.Instance);
        await enrollment.ApproveApplicationAsync(id, _registrar);

        var app = await _context.EnrollmentApplications.AsNoTracking().SingleAsync(a => a.ApplicationID == id);
        Assert.Equal(EnrollmentApplicationStatus.Active, app.Status);
        Assert.Equal(_registrar, app.ReviewedByUserID);
        Assert.Equal(2, (await _context.UserDetails.AsNoTracking().SingleAsync(d => d.UserID == _ana)).YearLevel);
        Assert.Empty(await enrollment.GetApprovedApplicationsAsync()); // nothing to "Create logins" for

        var listed = await enrollment.GetApplicationByIdAsync(id);
        Assert.True(listed!.IsReturning);
    }

    [Fact]
    public async Task PendingReturningForm_IsNotUsedForTheNextPrefill()
    {
        var dto = await ReadyToSend(_ana);
        dto.Form.MobileNumber = "09189999999";
        var (id, _, _) = await _service.SubmitAsync(_ana, dto, Open);
        (await _context.EnrollmentApplications.SingleAsync(a => a.ApplicationID == id)).Status = EnrollmentApplicationStatus.Rejected;
        await _context.SaveChangesAsync();

        // Rejected, so the next attempt starts again from the last accepted form.
        Assert.Equal("09171111111", (await _service.GetStatusAsync(_ana, Open)).Form!.MobileNumber);
    }
}
