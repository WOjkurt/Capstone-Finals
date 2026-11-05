using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

public class StudentEvaluationTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly StudentRecordService _records;
    private readonly Guid _student = Guid.NewGuid();
    private readonly Guid _teacher = Guid.NewGuid();
    private readonly Guid _sem1 = Guid.NewGuid();
    private readonly Guid _sem2 = Guid.NewGuid();
    private readonly Dictionary<string, Subject> _subjects = new();

    public StudentEvaluationTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _records = new StudentRecordService(_context);

        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS Information Technology" },
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSME", ProgramName = "BS ME" });
        _context.AcademicTerms.AddRange(
            new AcademicTerm { TermID = _sem1, SchoolYear = "2025-2026", Semester = 1 },
            new AcademicTerm { TermID = _sem2, SchoolYear = "2025-2026", Semester = 2 });
        _context.Users.Add(new User { UserID = _student, FirebaseUID = "fb1", Email = "s@x.com", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _student, Firstname = "Ana", Lastname = "Cruz", LRN = "1234", ProgramID = 1, YearLevel = 1 });

        AddSubject("IT 101", 1, 1, 3, 0);
        AddSubject("IT 102", 1, 1, 2, 1);
        AddSubject("GE 1", 1, 1, 3, 0, minor: true);
        AddSubject("IT 103", 1, 2, 3, 0);
        AddSubject("IT 104", 1, 2, 3, 0);
        AddSubject("IT 201", 2, 1, 3, 0);
        AddSubject("ME 101", 1, 1, 3, 0, program: 2);
        _subjects["IT 201"].StandingYear = 2;
        _subjects["IT 102"].LabHours = 3;
        _context.SubjectPrerequisites.AddRange(
            new SubjectPrerequisite { PrerequisiteID = Guid.NewGuid(), SubjectID = _subjects["IT 201"].SubjectID, PrerequisiteSubjectID = _subjects["IT 103"].SubjectID, RequisiteType = Api.Constants.RequisiteTypeConstants.Prerequisite },
            new SubjectPrerequisite { PrerequisiteID = Guid.NewGuid(), SubjectID = _subjects["IT 201"].SubjectID, PrerequisiteSubjectID = _subjects["IT 101"].SubjectID, RequisiteType = Api.Constants.RequisiteTypeConstants.Prerequisite },
            new SubjectPrerequisite { PrerequisiteID = Guid.NewGuid(), SubjectID = _subjects["IT 104"].SubjectID, PrerequisiteSubjectID = _subjects["IT 103"].SubjectID, RequisiteType = Api.Constants.RequisiteTypeConstants.Corequisite });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void AddSubject(string code, int year, int sem, decimal lec, decimal lab, bool minor = false, int program = 1)
    {
        var s = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code + " title", LecUnits = lec, LabUnits = lab, ProgramID = program, YearLevel = year, DefaultSemester = sem, IsMinor = minor };
        _context.Subjects.Add(s);
        _subjects[code] = s;
    }

    private async Task Take(string code, Guid term, int status, decimal? final = null)
    {
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = _subjects[code].SubjectID, TermID = term, ClassName = code + " A", CreatedAt = DateTime.UtcNow };
        var load = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = _student, ClassID = cls.ClassID, LoadStatus = status, CreatedAt = DateTime.UtcNow };
        _context.Classes.Add(cls);
        _context.StudyLoads.Add(load);
        if (final.HasValue)
            _context.Grades.Add(new Grade { GradeID = Guid.NewGuid(), StudyLoadID = load.StudyLoadID, FinalGrade = final, Remarks = final > 3.0m ? 2 : 1, SubmittedByUserID = _teacher });
        await _context.SaveChangesAsync();
    }

    [Fact]
    public async Task Evaluation_ListsTheCurriculumWithStatusesAndUnits()
    {
        await Take("IT 101", _sem1, StudyLoadStatus.Enrolled, 5.0m);   // failed first...
        await Take("IT 101", _sem2, StudyLoadStatus.Enrolled, 2.5m);   // ...then passed the retake
        await Take("IT 102", _sem1, StudyLoadStatus.Enrolled, 3.5m);
        await Take("IT 103", _sem2, StudyLoadStatus.Enrolled);         // no grade yet
        await Take("IT 104", _sem2, StudyLoadStatus.Dropped);
        await Take("IT 201", _sem2, StudyLoadStatus.Pending);          // pending is not an attempt
        _context.CreditedSubjects.Add(new CreditedSubject { CreditedSubjectID = Guid.NewGuid(), UserID = _student, SubjectID = _subjects["GE 1"].SubjectID, SourceSchool = "USC", Grade = "1.5", SchoolYear = "2024-2025", CreditedUnits = 3, RecordedByUserID = _teacher });
        await _context.SaveChangesAsync();

        var e = await _records.GetEvaluationAsync(_student);

        Assert.Equal(("Ana Cruz", "1234", "BSIT", 1), (e.FullName, e.Lrn, e.ProgramCode, e.YearLevel ?? 0));
        Assert.Equal(new[] { "GE 1", "IT 101", "IT 102", "IT 103", "IT 104", "IT 201" }, e.Subjects.Select(s => s.SubjectCode));
        var by = e.Subjects.ToDictionary(s => s.SubjectCode);
        Assert.Equal(("Passed", 2.5m, "2025-2026 (2nd Sem)"), (by["IT 101"].Status, by["IT 101"].FinalGrade, by["IT 101"].TermLabel));
        Assert.Equal(("Failed", 3.5m), (by["IT 102"].Status, by["IT 102"].FinalGrade));
        Assert.Equal("InProgress", by["IT 103"].Status);
        Assert.Equal("Dropped", by["IT 104"].Status);
        Assert.Equal(("NotTaken", null), (by["IT 201"].Status, by["IT 201"].TermLabel));
        Assert.Equal(("Credited", "USC", "1.5"), (by["GE 1"].Status, by["GE 1"].CreditedFrom, by["GE 1"].CreditedGrade));
        Assert.True(by["GE 1"].IsMinor);
        Assert.Equal("IT 101, IT 103, 2nd year standing", by["IT 201"].Prerequisites);
        Assert.Equal("IT 103", by["IT 104"].Corequisites);
        Assert.Null(by["IT 101"].Prerequisites);
        Assert.Equal(3m, by["IT 102"].LabHours);

        Assert.Equal(18m, e.TotalUnits);
        Assert.Equal(6m, e.EarnedUnits);      // IT 101 + GE 1
        Assert.Equal(3m, e.InProgressUnits);  // IT 103
        Assert.Equal(12m, e.RemainingUnits);
    }

    [Fact]
    public async Task Transcript_UsesTheEnrollmentForm_AndListsTermsOldestFirst()
    {
        var response = new EnrollmentResponse { ResponseID = Guid.NewGuid(), EmailAddress = "a@x.com", Timestamp = DateTime.UtcNow };
        var app = new EnrollmentApplication { ApplicationID = Guid.NewGuid(), ResponseID = response.ResponseID, ProgramID = 1, TermID = _sem1, StudentUserID = _student, CreatedAt = DateTime.UtcNow };
        _context.EnrollmentResponses.Add(response);
        _context.EnrollmentApplications.Add(app);
        _context.EnrollmentForms.Add(new EnrollmentForm
        {
            EnrollmentID = Guid.NewGuid(), ApplicationID = app.ApplicationID, FirstName = "Ana", MiddleName = "Reyes", LastName = "Cruz", Suffix = "",
            DateOfBirth = new DateOnly(2007, 5, 1), PlaceOfBirth = "Cebu City", Sex = "Female", CivilStatus = "Single", Nationality = "Filipino",
            MobileNumber = "0912", HouseStreet = "12 Rizal St", Barangay = "Punta Princesa", CityMunicipality = "Cebu City", Province = "Cebu", ZipCode = "6000",
            LastSchoolAttended = "Abellana National School", SchoolAddress = "Cebu", PreviousCollege = "N/A", PreviousCourse = "N/A", YearLevel = 1
        });
        await Take("IT 102", _sem2, StudyLoadStatus.Enrolled, 1.75m);
        await Take("IT 101", _sem1, StudyLoadStatus.Enrolled, 2.5m);
        await Take("IT 103", _sem1, StudyLoadStatus.Dropped);
        await Take("IT 104", _sem1, StudyLoadStatus.Withdrawn);
        await Take("IT 201", _sem2, StudyLoadStatus.Enrolled);   // no grade yet
        await Take("GE 1", _sem2, StudyLoadStatus.Pending);      // not on a transcript
        _context.CreditedSubjects.Add(new CreditedSubject { CreditedSubjectID = Guid.NewGuid(), UserID = _student, SubjectID = _subjects["GE 1"].SubjectID, SourceSchool = "USC", Grade = "1.5", CreditedUnits = 3, RecordedByUserID = _teacher });
        await _context.SaveChangesAsync();

        var t = await _records.GetTranscriptAsync(_student);

        Assert.Equal("CRUZ, Ana Reyes", t.FullName);
        Assert.Equal("12 Rizal St, Punta Princesa, Cebu City, Cebu", t.Address);
        Assert.Equal(("Abellana National School", "1st Semester, 2025-2026"), (t.EntranceData, t.DateAdmitted));
        Assert.Equal(new[] { "1st Semester, 2025-2026", "2nd Semester, 2025-2026" }, t.Terms.Select(x => x.Heading));
        Assert.Equal(new[] { ("IT 101", "2.50"), ("IT 103", "DO"), ("IT 104", "W") }, t.Terms[0].Rows.Select(r => (r.SubjectCode, r.Final)));
        Assert.Equal(new[] { ("IT 102", "1.75"), ("IT 201", "") }, t.Terms[1].Rows.Select(r => (r.SubjectCode, r.Final)));
        Assert.Equal(3m, t.Terms[1].Rows[0].Units);
        var credit = Assert.Single(t.Credits);
        Assert.Equal(("USC", "GE 1", "1.5"), (credit.SourceSchool, credit.Rows.Single().SubjectCode, credit.Rows.Single().Final));
    }

    private async Task AddForm()
    {
        var response = new EnrollmentResponse { ResponseID = Guid.NewGuid(), EmailAddress = "f@x.com", Timestamp = DateTime.UtcNow };
        var app = new EnrollmentApplication { ApplicationID = Guid.NewGuid(), ResponseID = response.ResponseID, ProgramID = 1, TermID = _sem1, StudentUserID = _student, CreatedAt = DateTime.UtcNow };
        _context.EnrollmentResponses.Add(response);
        _context.EnrollmentApplications.Add(app);
        _context.EnrollmentForms.Add(new EnrollmentForm
        {
            EnrollmentID = Guid.NewGuid(), ApplicationID = app.ApplicationID, FirstName = "Ana", MiddleName = "Reyes", LastName = "Cruz", Suffix = "",
            DateOfBirth = new DateOnly(2007, 5, 1), PlaceOfBirth = "Cebu City", Sex = "Female", CivilStatus = "Single", Nationality = "Filipino",
            MobileNumber = "0912", Barangay = "Punta Princesa", CityMunicipality = "Cebu City", Province = "Cebu", ZipCode = "6000",
            LastSchoolAttended = "Abellana National School", SchoolAddress = "Cebu", PreviousCollege = "N/A", PreviousCourse = "N/A", YearLevel = 1
        });
        await _context.SaveChangesAsync();
    }

    [Fact]
    public async Task PersonalDetails_SavedValuesWin_EmptyFieldsFallBackToTheForm()
    {
        await AddForm();
        await Take("IT 101", _sem2, StudyLoadStatus.Enrolled, 2.0m);

        var before = await _records.GetPersonalDetailsAsync(_student);
        Assert.Equal(("Reyes", "Punta Princesa, Cebu City, Cebu", "Abellana National School"), (before.MiddleName, before.Address, before.EntranceData));
        Assert.Contains("address", before.FromForm);
        Assert.True(before.HasEnrollmentForm);
        Assert.Equal("2nd Semester, 2025-2026", before.FirstTermEnrolled);
        Assert.Null(before.DateAdmitted);

        var after = await _records.UpdatePersonalDetailsAsync(_student, new Api.DTOs.Records.UpdatePersonalDetailsDto
        {
            Address = "  12 Rizal St, Cebu City ",
            EntranceData = "Cebu Normal University (transferee)",
            DateAdmitted = "1st Semester, 2024-2025",
            Sex = ""
        }, _teacher);

        Assert.Equal("12 Rizal St, Cebu City", after.Address);
        Assert.DoesNotContain("address", after.FromForm);
        Assert.Equal("Female", after.Sex);                 // empty means "use the form"
        Assert.Contains("sex", after.FromForm);
        Assert.NotNull(after.UpdatedAt);

        var t = await _records.GetTranscriptAsync(_student);
        Assert.Equal(("12 Rizal St, Cebu City", "Cebu Normal University (transferee)", "1st Semester, 2024-2025"), (t.Address, t.EntranceData, t.DateAdmitted));
        Assert.Equal("CRUZ, Ana Reyes", t.FullName);
    }

    [Fact]
    public async Task PersonalDetails_WithoutForm_RegistrarFillsThemIn()
    {
        var before = await _records.GetPersonalDetailsAsync(_student);
        Assert.False(before.HasEnrollmentForm);
        Assert.Null(before.Address);

        await _records.UpdatePersonalDetailsAsync(_student, new Api.DTOs.Records.UpdatePersonalDetailsDto
        {
            MiddleName = "Lopez", Address = "Talisay City", DateOfBirth = new DateOnly(2006, 2, 3), Nationality = "Filipino"
        }, _teacher);
        var t = await _records.GetTranscriptAsync(_student);

        Assert.Equal(("CRUZ, Ana Lopez", "Talisay City", new DateOnly(2006, 2, 3)), (t.FullName, t.Address, t.DateOfBirth ?? default));
        await Assert.ThrowsAsync<InvalidOperationException>(() => _records.UpdatePersonalDetailsAsync(_student,
            new Api.DTOs.Records.UpdatePersonalDetailsDto { DateOfBirth = new DateOnly(1800, 1, 1) }, _teacher));
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _records.UpdatePersonalDetailsAsync(Guid.NewGuid(),
            new Api.DTOs.Records.UpdatePersonalDetailsDto(), _teacher));
    }

    [Fact]
    public async Task SetSex_KeepsOtherDetails_AndOnlyAcceptsMaleOrFemale()
    {
        await _records.UpdatePersonalDetailsAsync(_student, new Api.DTOs.Records.UpdatePersonalDetailsDto { Address = "Talisay City" }, _teacher);

        await _records.SetSexAsync(_student, "f", _teacher);

        var d = await _records.GetPersonalDetailsAsync(_student);
        Assert.Equal(("Female", "Talisay City"), (d.Sex, d.Address));
        await Assert.ThrowsAsync<InvalidOperationException>(() => _records.SetSexAsync(_student, "x", _teacher));
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _records.SetSexAsync(Guid.NewGuid(), "Male", _teacher));
    }

    [Fact]
    public async Task MissingSex_ListsEnrolledStudentsWithoutIt()
    {
        await Take("IT 101", _sem1, StudyLoadStatus.Enrolled);
        var reports = new ReportService(_context);

        var missing = Assert.Single(await reports.GetStudentsMissingSexAsync(_sem1));
        Assert.Equal(("CRUZ, Ana", "BSIT"), (missing.StudentName, missing.ProgramCode));

        await _records.SetSexAsync(_student, "Female", _teacher);
        Assert.Empty(await reports.GetStudentsMissingSexAsync(_sem1));
        Assert.Empty(await reports.GetStudentsMissingSexAsync(_sem2));   // not enrolled that term
    }

    private void Graded(string code, Guid term, int status, decimal? final, DateTime submitted)
    {
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = _subjects[code].SubjectID, TermID = term, ClassName = code + " A", CreatedAt = DateTime.UtcNow };
        var load = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = _student, ClassID = cls.ClassID, LoadStatus = status, CreatedAt = DateTime.UtcNow };
        _context.Classes.Add(cls);
        _context.StudyLoads.Add(load);
        if (final.HasValue)
            _context.Grades.Add(new Grade { GradeID = Guid.NewGuid(), StudyLoadID = load.StudyLoadID, FinalGrade = final, Remarks = final > 3.0m ? 2 : 1, SubmittedByUserID = _teacher, DateSubmitted = submitted });
        _context.SaveChanges();
    }

    [Fact]
    public async Task Standing_SuggestsIrregular_ThenRegularAfterSixUnitsOfBackMajorsPassed()
    {
        var old = DateTime.UtcNow.AddDays(-30);
        Graded("IT 101", _sem1, StudyLoadStatus.Enrolled, 5.0m, old);   // failed major (3 units)
        Graded("IT 104", _sem1, StudyLoadStatus.Dropped, null, old);    // dropped major (3 units)
        Graded("GE 1", _sem1, StudyLoadStatus.Enrolled, 5.0m, old);     // failed minor (does not count)

        var s1 = await _records.GetStandingAsync(_student);
        Assert.True(s1.IsRegular);
        Assert.Equal("MarkIrregular", s1.Suggestion);
        Assert.Equal(new[] { "GE 1", "IT 101", "IT 104" }, s1.UnresolvedSubjects);

        var s2 = await _records.SetStandingAsync(_student, isRegular: false);
        Assert.NotNull(s2.IrregularSince);
        Assert.Null(s2.Suggestion);

        Graded("IT 101", _sem2, StudyLoadStatus.Enrolled, 2.0m, DateTime.UtcNow.AddMinutes(1));
        Graded("GE 1", _sem2, StudyLoadStatus.Enrolled, 2.0m, DateTime.UtcNow.AddMinutes(1));
        var s3 = await _records.GetStandingAsync(_student);
        Assert.Equal((3m, (string?)null), (s3.BackMajorUnitsPassed, s3.Suggestion));   // minors don't count

        Graded("IT 104", _sem2, StudyLoadStatus.Enrolled, 1.5m, DateTime.UtcNow.AddMinutes(1));
        var s4 = await _records.GetStandingAsync(_student);
        Assert.Equal((6m, "MarkRegular"), (s4.BackMajorUnitsPassed, s4.Suggestion));
        Assert.Equal(new[] { "IT 101", "IT 104" }, s4.CountedSubjects);
        Assert.True(Assert.Single(await _records.GetIrregularStudentsAsync()).ReadyToBeRegular);

        var s5 = await _records.SetStandingAsync(_student, isRegular: true);
        Assert.Equal((true, (DateTime?)null, (string?)null), (s5.IsRegular, s5.IrregularSince, s5.Suggestion));
        Assert.Empty(await _records.GetIrregularStudentsAsync());
    }

    [Fact]
    public async Task Standing_BackMajorsPassedBeforeBecomingIrregular_DoNotCount()
    {
        Graded("IT 101", _sem1, StudyLoadStatus.Enrolled, 5.0m, DateTime.UtcNow.AddDays(-30));
        Graded("IT 101", _sem2, StudyLoadStatus.Enrolled, 2.0m, DateTime.UtcNow.AddDays(-10));

        var s = await _records.SetStandingAsync(_student, isRegular: false);

        Assert.Equal(0m, s.BackMajorUnitsPassed);
        Assert.Empty(s.UnresolvedSubjects);
    }

    [Fact]
    public async Task Transcript_WithoutForm_FallsBackToTheAccountName()
    {
        var t = await _records.GetTranscriptAsync(_student);

        Assert.Equal("CRUZ, Ana", t.FullName);
        Assert.Null(t.Address);
        Assert.Null(t.DateAdmitted);
        Assert.Empty(t.Terms);
        Assert.IsType<NotFoundObjectResult>(await new StudentRecordsController(_records).Transcript(Guid.NewGuid()));
    }

    [Fact]
    public async Task PartialAndCrossEnrolledCredits_ShowOnEvaluationAndTranscript()
    {
        await Take("IT 101", _sem1, StudyLoadStatus.Enrolled, 2.0m);
        _context.CreditedSubjects.AddRange(
            new CreditedSubject { CreditedSubjectID = Guid.NewGuid(), UserID = _student, SubjectID = _subjects["IT 103"].SubjectID, SourceSchool = "CTU", Grade = "1.5", CreditedUnits = 2, SchoolYear = "2024-2025", RecordedByUserID = _teacher },
            new CreditedSubject { CreditedSubjectID = Guid.NewGuid(), UserID = _student, SubjectID = _subjects["GE 1"].SubjectID, SourceSchool = "USC", Grade = "1.25", CreditedUnits = 3, Kind = CreditKinds.CrossEnrollment, TermID = _sem1, SchoolYear = "2025-2026", RecordedByUserID = _teacher });
        await _context.SaveChangesAsync();

        var e = await _records.GetEvaluationAsync(_student);
        var by = e.Subjects.ToDictionary(s => s.SubjectCode);
        Assert.Equal(("PartiallyCredited", 2m), (by["IT 103"].Status, by["IT 103"].CreditedUnits ?? 0));
        Assert.Equal(("CrossEnrolled", "2025-2026 (1st Sem)", "USC"), (by["GE 1"].Status, by["GE 1"].TermLabel, by["GE 1"].CreditedFrom));
        Assert.Equal(3m + 2m + 3m, e.EarnedUnits);   // IT 101 passed, IT 103 partly, GE 1 cross-enrolled

        var t = await _records.GetTranscriptAsync(_student);
        var sem1 = Assert.Single(t.Terms);
        Assert.Equal("1st Semester, 2025-2026", sem1.Heading);
        Assert.Equal(new[] { "GE 1", "IT 101" }, sem1.Rows.Select(r => r.SubjectCode));
        Assert.Equal(("GE 1 title (cross-enrolled at USC)", "1.25", 3m), (sem1.Rows[0].SubjectTitle, sem1.Rows[0].Final, sem1.Rows[0].Units));
        var ctu = Assert.Single(t.Credits);
        Assert.Equal(("CTU", 2m), (ctu.SourceSchool, ctu.Rows.Single().Units));

        var transferees = await new ReportService(_context).GetTransfereesAsync();
        Assert.Equal(new[] { "CTU" }, Assert.Single(transferees).PreviousSchools);
    }

    [Fact]
    public async Task Evaluation_StudentWithoutProgram_Is400_UnknownStudent_Is404()
    {
        var details = await _context.UserDetails.SingleAsync(u => u.UserID == _student);
        details.ProgramID = null;
        await _context.SaveChangesAsync();
        var controller = new StudentRecordsController(_records);

        Assert.IsType<BadRequestObjectResult>(await controller.Evaluation(_student));
        Assert.IsType<NotFoundObjectResult>(await controller.Evaluation(Guid.NewGuid()));
    }
}
