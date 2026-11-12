using Microsoft.Extensions.Logging.Abstractions;
using Api.Repositories;
using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

// The Google Form's responses spreadsheet, saved as students' enrollment forms.
public class EnrollmentFormsImportTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly Guid _registrar = Guid.NewGuid();
    private readonly Guid _ana = Guid.NewGuid();
    private readonly Guid _ben = Guid.NewGuid();
    private readonly Guid _old = Guid.NewGuid();
    private readonly Guid _open = Guid.NewGuid();

    // The real form's column titles, in its order.
    private static readonly string[] Header =
    {
        "Timestamp", "Student type", "Enter LRN ", "Academic Year", "Incoming Year Level", "Incoming Course", "Email Address",
        "First Name", "Middle Name", "Last Name", "Suffix (ex. Jr., Sr., III)", "Gender", "Age", "Blood Type", "Date of Birth",
        "Place of Birth", "Nationality", "Religion", "Civil Status", "Mobile Number", "Input your Facebook Name",
        "House No./ Unit No. & Street", "Barangay", "City of Municipality", "Province", "Zip Code",
        "House No. / Unit No. & Street", "Barangay 2", "City/ Municipality", "Province 2", "Zip Code 2",
        "Name of Last School Attended", "Address of Last School Attended", "Year of Last School Attended",
        "Program/Track & Strand/ Specialization/ NA or Not Applicable", "Previous College (for Transferees Only)",
        "Previous Course (for Transferees Only)",
        "First Name 2", "Middle Name 2", "Last Name 2", "Mobile Number 2", "Email Address 2", "Date of Birth 2", "Occupation",
        "Workplace or Company", "Facebook/ Messenger Account (if any)",
        "First Name 3", "Middle Name 3", "Last Name 3", "Mobile Number 3", "Email Address 3", "Date of Birth 3", "Occupation 2",
        "Workplace or Company 2", "Facebook/ Messenger Account (if any) 2",
        "First Name 4", "Middle Name 4", "Last Name 4", "Mobile Number 4", "Email Address 4", "Occupation 3", "Relationship",
        "This student is living with guardian",
        "Birth Order", "Number of Siblings", "Family Status", "Present Medical Conditions (Please check all that applies)",
        "Past Medical History (Please check all that applies)", "Immunization History (Please check all that applies)",
        "Please note any medical conditions presents in either mother's or father's side. (if any)", "Ongoing Medications (if any)",
        "Developmental / Psychological Conditions / Diagnosis (if any)", "Medical Conditions / Diagnosis (if any)",
    };

    public EnrollmentFormsImportTests()
    {
        _context = new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        var old = new AcademicTerm { TermID = _old, SchoolYear = "2025-2026", Semester = 2 };
        _context.AcademicTerms.AddRange(old, new AcademicTerm { TermID = _open, SchoolYear = "2026-2027", Semester = 1, IsActive = true });
        Student(_ana, "23017245", "Ana Marie", "Cruz", "ana.cruz@dbtc-cebu.edu.ph");
        Student(_ben, "23017246", "Ben", "Dela Reyes", "");
        var cls = new Class { ClassID = Guid.NewGuid(), TermID = _old, SubjectID = Guid.NewGuid(), ClassName = "A" };
        _context.Classes.Add(cls);
        _context.StudyLoads.Add(new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = _ana, ClassID = cls.ClassID, LoadStatus = StudyLoadStatus.Enrolled });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void Student(Guid id, string studentId, string first, string last, string email)
    {
        _context.Users.Add(new User { UserID = id, FirebaseUID = "pending:" + id, Email = email, Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(), UserID = id, Firstname = first, Lastname = last, StudentID = studentId, ProgramID = 1, YearLevel = 3
        });
    }

    private static string[] Answer(string timestamp, string type, string email, string first, string last, string father = "JUAN")
    {
        var row = new string[Header.Length];
        Array.Fill(row, "");
        void Set(string title, string v) => row[Array.IndexOf(Header, title)] = v;
        Set("Timestamp", timestamp);
        Set("Student type", type);
        Set("Academic Year", "2026-2027");
        Set("Incoming Year Level", "Final Year");
        Set("Incoming Course", "BSIT (Bachelor of Science in Information Technology)");
        Set("Email Address", email);
        Set("First Name", first);
        Set("Middle Name", "SANTOS");
        Set("Last Name", last);
        Set("Gender", "Female");
        Set("Age", "21");
        Set("Date of Birth", "37987");             // 2004-01-01
        Set("Place of Birth", "Cebu City");
        Set("Nationality", "Filipino");
        Set("Civil Status", "Single");
        Set("Mobile Number", "9.171234567E9");
        Set("House No./ Unit No. & Street", "12 Rizal St.");
        Set("Barangay", "Lahug");
        Set("City of Municipality", "Cebu City");
        Set("Province", "Cebu");
        Set("Zip Code", "6000");
        Set("House No. / Unit No. & Street", "Purok 3");
        Set("City/ Municipality", "Bogo");
        Set("Name of Last School Attended", "Cebu NHS");
        Set("Address of Last School Attended", "Cebu City");
        Set("Year of Last School Attended", "2022");
        Set("First Name 2", father);
        Set("Last Name 2", last);
        Set("Occupation", "Driver");
        Set("First Name 3", "MARIA");
        Set("Last Name 3", last);
        Set("Occupation 2", "Vendor");
        Set("Present Medical Conditions (Please check all that applies)", "Asthma, Allergies");
        return row;
    }

    private Task<Api.DTOs.Enrollment.EnrollmentFormsImportResultDto> Run(bool dryRun, params string[][] answers) =>
        new EnrollmentFormsImportService(_context).ImportAsync(
            RecordsImportTests.Workbook(("Form Responses 1", new[] { Header }.Concat(answers).ToArray())), dryRun, _registrar);

    [Fact]
    public async Task Answers_AreMatchedByEmailOrName_AndOthersAreLeftOut()
    {
        var r = await Run(true,
            Answer("46000.5", "Old Student", "ANA.CRUZ@dbtc-cebu.edu.ph", "anna", "x"),       // email wins over a different name
            Answer("46001.5", "Old Student", "ben@gmail.com", "BEN", "DELA REYES"),           // by name
            Answer("46002.5", "New Student", "new@gmail.com", "Carlo", "Lim"));               // not in the system
        Assert.Equal(2, r.Forms);
        Assert.Equal(1, r.NotInSystem);
        Assert.Contains(r.Rows, x => x.StudentId == "23017245" && x.MatchedBy == "school email" && x.Contacts == 2);
        Assert.Contains(r.Rows, x => x.StudentId == "23017246" && x.MatchedBy == "name");
        Assert.Contains(r.Problems, p => p.Row == 4 && p.Message.Contains("Form responses instead"));
        Assert.Equal(0, await _context.EnrollmentForms.CountAsync());
    }

    [Fact]
    public async Task Import_SavesTheForm_UnderAnOldTerm_AndTheDetailsTabUsesIt()
    {
        var r = await Run(false, Answer("46000.5", "Old Student", "ana.cruz@dbtc-cebu.edu.ph", "ANA MARIE", "CRUZ"));
        Assert.Equal(1, r.Forms);

        var app = await _context.EnrollmentApplications.SingleAsync();
        Assert.Equal(_ana, app.StudentUserID);
        Assert.Equal(_old, app.TermID); // never the open term, so online enrollment isn't blocked
        Assert.Equal(EnrollmentApplicationStatus.Active, app.Status);
        Assert.True((await _context.EnrollmentResponses.SingleAsync()).IsProcessed);

        var form = await _context.EnrollmentForms.SingleAsync();
        Assert.Equal("Santos", form.MiddleName);
        Assert.Equal(new DateOnly(2004, 1, 1), form.DateOfBirth);
        Assert.Equal("Female", form.Sex);
        Assert.Equal("9171234567", form.MobileNumber);
        Assert.Equal("12 Rizal St.", form.HouseStreet);
        Assert.Equal("Purok 3", form.ProvHouseStreet);
        Assert.Equal("Bogo", form.ProvCityMunicipality);
        Assert.Equal("Cebu City", form.CityMunicipality);
        Assert.Equal(new DateOnly(2022, 1, 1), form.YearGraduated);
        Assert.Equal(3, form.YearLevel);          // "Final Year" isn't a year level: the student's own is kept
        Assert.Equal(2, form.StudentType);
        Assert.Equal(new[] { "Asthma", "Allergies" }, form.FamilyMedicalConditionsSelected);
        var contacts = await _context.Contacts.OrderBy(c => c.RelationType).ToListAsync();
        Assert.Equal(new[] { 1, 2 }, contacts.Select(c => c.RelationType));
        Assert.Equal("Juan", contacts[0].FirstName);
        Assert.Equal("Vendor", contacts[1].Occupation);

        var details = await new StudentRecordService(_context).GetPersonalDetailsAsync(_ana);
        Assert.Equal("Santos", details.MiddleName);
        Assert.Equal("12 Rizal St., Lahug, Cebu City, Cebu", details.Address);
        Assert.Equal("Cebu NHS", details.EntranceData);

        // The Details tab's read-only "Enrollment form" section shows the same answers.
        var enrollment = new EnrollmentService(_context, new EnrollmentResponseRepository(_context),
            new EnrollmentApplicationRepository(_context), new EnrollmentFormRepository(_context),
            new ContactRepository(_context), new UserDetailsRepository(_context), new UserRepository(_context),
            NullLogger<EnrollmentService>.Instance);
        var latest = await enrollment.GetLatestFormForStudentAsync(_ana);
        Assert.NotNull(latest);
        Assert.Equal("Cebu NHS", latest!.Form!.LastSchoolAttended);
        Assert.Equal(2, latest.Contacts.Count);
        Assert.Null(await enrollment.GetLatestFormForStudentAsync(_ben));
    }

    [Fact]
    public async Task ImportingAgain_ChangesNothing_AndOnlyTheNewestAnswerIsKept()
    {
        string[][] answers =
        {
            Answer("46000.25", "Old Student", "ana.cruz@dbtc-cebu.edu.ph", "Ana Marie", "Cruz", father: "OLDER"),
            Answer("46000.75", "Old Student", "ana.cruz@dbtc-cebu.edu.ph", "Ana Marie", "Cruz", father: "NEWER"),
        };
        var r = await Run(false, answers);
        Assert.Equal(1, r.Forms);
        Assert.Equal(1, r.OlderAnswersSkipped);
        Assert.Equal("Newer", (await _context.Contacts.SingleAsync(c => c.RelationType == 1)).FirstName);

        var again = await Run(false, answers);
        Assert.Equal(0, again.Forms);
        Assert.Equal(1, again.AlreadyImported);
        Assert.Equal(1, await _context.EnrollmentForms.CountAsync());
    }

    [Fact]
    public async Task TwoStudentsWithTheSameName_AreNotGuessed()
    {
        Student(Guid.NewGuid(), "23017247", "Ben", "Dela Reyes", "");
        await _context.SaveChangesAsync();
        var r = await Run(true, Answer("46001.5", "Old Student", "ben@gmail.com", "Ben", "Dela Reyes"));
        Assert.Equal(0, r.Forms);
        Assert.Contains("2 students are named", r.Problems.Single().Message);
    }

    [Fact]
    public async Task AFileThatIsNotTheForm_IsAClearError()
    {
        var ex = await Assert.ThrowsAsync<InvalidDataException>(() => new EnrollmentFormsImportService(_context)
            .ImportAsync(RecordsImportTests.Workbook(("Sheet1", new[] { new[] { "Student ID", "Grade" } })), true, _registrar));
        Assert.Contains("First Name", ex.Message);
    }
}
