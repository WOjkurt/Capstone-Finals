using System.Text;
using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Credits;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

// The registrar's list of credited subjects (transferees, shiftees, cross-enrollment) imported at once.
public class CreditsImportTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly Guid _registrar = Guid.NewGuid();
    private readonly Guid _ana = Guid.NewGuid();
    private readonly Guid _ben = Guid.NewGuid();
    private readonly Guid _mt2021 = Guid.NewGuid();
    private readonly Guid _mt2026 = Guid.NewGuid();
    private readonly Guid _term = Guid.NewGuid();
    private readonly Dictionary<string, Guid> _subjects = new();

    public CreditsImportTests()
    {
        _context = new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 1, ProgramCode = "BTVTED-MT", ProgramName = "BTVTEd MT" },
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.Curricula.AddRange(
            new Curriculum { CurriculumID = _mt2021, ProgramID = 1, Name = "MT 2021", EffectiveFromYear = 2021 },
            new Curriculum { CurriculumID = _mt2026, ProgramID = 1, Name = "MT 2026", EffectiveFromYear = 2026 });
        Subject("GEC 101A", 1, _mt2021);
        Subject("GEC 101A", 1, _mt2026, "2026 version");
        Subject("GEC 102", 1, _mt2021);
        Subject("NSTP 01A", 1, _mt2021);
        Subject("IT 101", 2, null);
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _term, SchoolYear = "2024-2025", Semester = 3 });
        Student(_ana, "25060208", 1, _mt2021, "Ana", "Cruz");
        Student(_ben, "8090037", 1, null, "Ben", "Reyes");
        _context.AccreditedSchools.Add(new AccreditedSchool { SchoolID = Guid.NewGuid(), Name = "University of Cebu" });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void Subject(string code, int program, Guid? curriculum, string? title = null)
    {
        var id = Guid.NewGuid();
        _context.Subjects.Add(new Subject
        {
            SubjectID = id, SubjectCode = code, SubjectTitle = title ?? code, LecUnits = 3, ProgramID = program,
            CurriculumID = curriculum ?? Guid.NewGuid(), YearLevel = 1, DefaultSemester = 1
        });
        _subjects.TryAdd($"{code}|{curriculum}", id);
    }

    private void Student(Guid id, string studentId, int program, Guid? curriculum, string first, string last)
    {
        _context.Users.Add(new User { UserID = id, FirebaseUID = "pending:" + id, Email = "", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(), UserID = id, Firstname = first, Lastname = last, StudentID = studentId,
            ProgramID = program, CurriculumID = curriculum, YearLevel = 2
        });
    }

    private static readonly string[] Header =
        { "Student ID", "DBTC Subject Code", "School", "Their Subject Code", "Grade", "School Year", "Units Credited", "Type", "DBTC Term" };

    private CreditsImportService Service() => new(_context, new CreditedSubjectService(_context));

    private Task<CreditsImportResultDto> RunXlsx(bool dryRun, params string[][] rows) =>
        Service().ImportAsync(RecordsImportTests.Workbook(("Credits", new[] { Header }.Concat(rows).ToArray())), "credits.xlsx", dryRun, _registrar);

    [Fact]
    public async Task DryRun_ChecksEveryRow_AndSavesNothing()
    {
        var r = await RunXlsx(true,
            new[] { "2.5060208E7", "GEC 101A", "university of cebu", "ENG 1", "1.5", "2023-2024", "", "", "" },
            new[] { "25060208", "gec-102", "UC", "", "2.0", "", "2", "Transfer", "" },
            new[] { "25060208", "MT 999", "UC", "", "", "", "", "", "" },
            new[] { "99999999", "GEC 101A", "UC", "", "", "", "", "", "" },
            new[] { "", "GEC 101A", "UC", "", "", "", "", "", "" },
            new[] { "25060208", "NSTP 01A", "", "", "", "", "", "", "" },
            new[] { "25060208", "GEC 102", "UC", "", "", "", "", "", "" },
            new[] { "25060208", "NSTP 01A", "UC", "", "", "", "9", "", "" });

        Assert.Equal(2, r.Credits);
        Assert.Equal(1, r.Students);
        Assert.Equal(6, r.TotalProblems);
        Assert.Contains(r.Problems, p => p.Row == 4 && p.Message.Contains("MT 999"));
        Assert.Contains(r.Problems, p => p.Row == 5 && p.Message.Contains("No student with Student ID 99999999"));
        Assert.Contains(r.Problems, p => p.Row == 6 && p.Message == "No Student ID.");
        Assert.Contains(r.Problems, p => p.Row == 7 && p.Message.Contains("name of the school"));
        Assert.Contains(r.Problems, p => p.Row == 8 && p.Message.Contains("already on row 3"));
        Assert.Contains(r.Problems, p => p.Row == 9 && p.Message.Contains("has only 3 units"));
        // Full units when blank; the accredited list's spelling is used; the student's own curriculum's subject.
        var gec = r.Rows.Single(x => x.SubjectCode == "GEC 101A");
        Assert.Equal(3, gec.CreditedUnits);
        Assert.Equal("University of Cebu", gec.SourceSchool);
        Assert.Equal("GEC 101A", gec.SubjectTitle);
        Assert.Equal(2, r.Rows.Single(x => x.SubjectCode == "GEC 102").CreditedUnits);
        Assert.Equal(0, await _context.CreditedSubjects.CountAsync());
    }

    [Fact]
    public async Task Import_Saves_AndImportingAgainSkipsWhatIsCredited()
    {
        string[][] rows =
        {
            new[] { "25060208", "GEC 101A", "UC", "ENG 1", "1.5", "2023-2024", "", "", "" },
            new[] { "8090037", "GEC 102", "CTU", "", "", "", "", "cross-enrolled", "Summer 2024-2025" },
        };
        var r = await RunXlsx(false, rows);
        Assert.Equal(2, r.Credits);
        Assert.Equal(0, r.TotalProblems);

        var ana = await _context.CreditedSubjects.SingleAsync(c => c.UserID == _ana);
        Assert.Equal(_subjects[$"GEC 101A|{_mt2021}"], ana.SubjectID);
        Assert.Equal("ENG 1", ana.SourceSubjectCode);
        Assert.Equal("1.5", ana.Grade);
        Assert.Equal(CreditKinds.Transfer, ana.Kind);
        var ben = await _context.CreditedSubjects.SingleAsync(c => c.UserID == _ben);
        Assert.Equal(CreditKinds.CrossEnrollment, ben.Kind);
        Assert.Equal(_term, ben.TermID);
        Assert.Equal("2024-2025", ben.SchoolYear);

        var again = await RunXlsx(false, rows);
        Assert.Equal(0, again.Credits);
        Assert.Equal(2, again.AlreadyCredited);
        Assert.Equal(2, await _context.CreditedSubjects.CountAsync());
    }

    [Fact]
    public async Task CrossEnrollment_NeedsAKnownTerm_AndTypeMustBeUnderstood()
    {
        var r = await RunXlsx(true,
            new[] { "25060208", "GEC 101A", "UC", "", "", "", "", "Cross-enrollment", "" },
            new[] { "25060208", "GEC 102", "UC", "", "", "", "", "Cross", "1st Sem 2030-2031" },
            new[] { "25060208", "NSTP 01A", "UC", "", "", "", "", "Audit", "" });
        Assert.Equal(0, r.Credits);
        Assert.Contains(r.Problems, p => p.Row == 2 && p.Message.Contains("needs the DBTC term"));
        Assert.Contains(r.Problems, p => p.Row == 3 && p.Message.Contains("not in the system"));
        Assert.Contains(r.Problems, p => p.Row == 4 && p.Message.Contains("Type \"Audit\""));
    }

    [Fact]
    public async Task Csv_IsReadToo_WithHeaderAliases()
    {
        var csv = "﻿Student No.,Subject Code,Other School,Grade,Units\n25060208,GEC 102,\"Cebu Technological University, Main\",1.75,3\n";
        var r = await Service().ImportAsync(new MemoryStream(Encoding.UTF8.GetBytes(csv)), "credits.csv", false, _registrar);
        Assert.Equal(1, r.Credits);
        var c = await _context.CreditedSubjects.SingleAsync();
        Assert.Equal("Cebu Technological University, Main", c.SourceSchool);
        Assert.Equal("1.75", c.Grade);
    }

    [Fact]
    public async Task NoHeader_IsAClearError()
    {
        var ex = await Assert.ThrowsAsync<InvalidDataException>(() =>
            Service().ImportAsync(RecordsImportTests.Workbook(("Sheet1", new[] { new[] { "a", "b" } })), "x.xlsx", true, _registrar));
        Assert.Contains("Student ID", ex.Message);
    }

    [Theory]
    [InlineData("1st Sem 2024-2025", "2024-2025", 1)]
    [InlineData("2024-2025 (2nd Sem)", "2024-2025", 2)]
    [InlineData("SUMMER_2023-2024", "2023-2024", 3)]
    [InlineData("First Semester, 2022 - 2023", "2022-2023", 1)]
    public void TermOf_ReadsCommonSpellings(string text, string year, int sem)
    {
        Assert.Equal((year, sem), CreditsImportService.TermOf(text));
    }

    [Fact]
    public async Task Controller_RejectsOtherFiles_AndLogsEachCredit()
    {
        var controller = new CreditsImportController(Service());
        var http = new DefaultHttpContext();
        http.Items["user_id"] = _registrar;
        http.Items["role"] = RoleUtils.Registrar;
        http.Request.ContentType = "multipart/form-data; boundary=x";
        var pdf = new FormFileCollection { new FormFile(new MemoryStream(new byte[] { 1 }), 0, 1, "file", "credits.pdf") };
        http.Request.Form = new FormCollection(new(), pdf);
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        Assert.IsType<BadRequestObjectResult>(await controller.ImportCredits());

        var bytes = RecordsImportTests.Workbook(("Credits", new[] { Header, new[] { "25060208", "GEC 102", "UC", "", "", "", "", "", "" } })).ToArray();
        var files = new FormFileCollection { new FormFile(new MemoryStream(bytes), 0, bytes.Length, "file", "credits.xlsx") };
        http.Request.Form = new FormCollection(new() { ["dryRun"] = "false" }, files);
        var ok = Assert.IsType<OkObjectResult>(await controller.ImportCredits());
        Assert.Equal(1, ((CreditsImportResultDto)ok.Value!).Credits);
        Assert.Equal(1, await _context.CreditedSubjects.CountAsync());
    }
}
