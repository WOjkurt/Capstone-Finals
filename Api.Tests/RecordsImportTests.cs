using System.Globalization;
using System.IO.Compression;
using System.Security.Claims;
using System.Text;
using Api.Auth;
using Api.Common;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

// Old students and their grades come from the registrar's Excel files (GRADES.xlsx, STUDENTS.xlsx).
public class RecordsImportTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly Guid _registrar = Guid.NewGuid();
    private readonly Guid _mt2021 = Guid.NewGuid();
    private readonly Guid _mt2026 = Guid.NewGuid();
    private readonly Guid _it2023 = Guid.NewGuid();

    public RecordsImportTests()
    {
        _context = new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 1, ProgramCode = "BTVTED-MT", ProgramName = "BTVTEd MT" },
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.Curricula.AddRange(
            new Curriculum { CurriculumID = _mt2021, ProgramID = 1, Name = "MT 2021", EffectiveFromYear = 2021 },
            new Curriculum { CurriculumID = _mt2026, ProgramID = 1, Name = "MT 2026", EffectiveFromYear = 2026 },
            new Curriculum { CurriculumID = _it2023, ProgramID = 2, Name = "BSIT 2023", EffectiveFromYear = 2023 });
        Subject(1, _mt2021, "MT 101A");
        Subject(1, _mt2021, "MT 101WS");
        Subject(1, _mt2021, "NSTP 01A");
        Subject(1, _mt2021, "GEC 112B-ELEC 3");
        Subject(1, _mt2026, "MT 101");
        Subject(2, _it2023, "IT 101A");
        _context.AcademicTerms.Add(new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 1, IsActive = true });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void Subject(int program, Guid curriculum, string code) => _context.Subjects.Add(new Subject
    {
        SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code, LecUnits = 3, ProgramID = program,
        CurriculumID = curriculum, YearLevel = 1, DefaultSemester = 1
    });

    // ── A tiny .xlsx writer (inline strings), enough for these tests ──

    /// <summary>0 → A, 25 → Z, 26 → AA.</summary>
    private static string ColumnName(int index)
    {
        var name = "";
        for (index++; index > 0; index = (index - 1) / 26) name = (char)('A' + (index - 1) % 26) + name;
        return name;
    }

    internal static MemoryStream Workbook(params (string Name, string[][] Rows)[] sheets)
    {
        var ms = new MemoryStream();
        using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, leaveOpen: true))
        {
            void Write(string path, string xml)
            {
                using var w = new StreamWriter(zip.CreateEntry(path).Open(), new UTF8Encoding(false));
                w.Write(xml);
            }
            const string ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
            const string r = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
            Write("xl/workbook.xml", $"<workbook xmlns=\"{ns}\" xmlns:r=\"{r}\"><sheets>" +
                string.Concat(sheets.Select((s, i) => $"<sheet name=\"{s.Name}\" sheetId=\"{i + 1}\" r:id=\"rId{i + 1}\"/>")) + "</sheets></workbook>");
            Write("xl/_rels/workbook.xml.rels", "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
                string.Concat(sheets.Select((s, i) => $"<Relationship Id=\"rId{i + 1}\" Target=\"worksheets/sheet{i + 1}.xml\" Type=\"x\"/>")) + "</Relationships>");
            for (int i = 0; i < sheets.Length; i++)
            {
                var sb = new StringBuilder($"<worksheet xmlns=\"{ns}\"><sheetData>");
                for (int row = 0; row < sheets[i].Rows.Length; row++)
                {
                    sb.Append($"<row r=\"{row + 1}\">");
                    for (int c = 0; c < sheets[i].Rows[row].Length; c++)
                    {
                        var v = System.Security.SecurityElement.Escape(sheets[i].Rows[row][c]);
                        var cell = $"{ColumnName(c)}{row + 1}";
                        // Numbers as Excel stores them (e.g. 2.5060208E7), text as inline strings.
                        sb.Append(double.TryParse(v, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out _)
                            ? $"<c r=\"{cell}\"><v>{v}</v></c>"
                            : $"<c r=\"{cell}\" t=\"inlineStr\"><is><t>{v}</t></is></c>");
                    }
                    sb.Append("</row>");
                }
                Write($"xl/worksheets/sheet{i + 1}.xml", sb.Append("</sheetData></worksheet>").ToString());
            }
        }
        ms.Position = 0;
        return ms;
    }

    private static readonly string[] GradesHeader =
        { "STUDENT NO.", "LASTNAME", "FIRSTNAME", "MIDDLE NAME", "GENDER", "COURSE", "YEAR", "SUBJECTS", "SUBJECT DESCRIPTIONS", "UNITS", "MG", "FG" };

    private static string[] G(string id, string last, string course, string code, string mg, string fg, string year = "1.0") =>
        new[] { id, last, "ANA MARIE", "SANTOS", "F", course, year, code, code, "3.0", mg, fg };

    private MemoryStream GradesFile() => Workbook(
        ("1ST SEM_2025-2026", new[]
        {
            GradesHeader,
            G("2.5060208E7", "DELA CRUZ", "BTVTEd /MT", "MT 101A", "1.7", "1.5"),
            G("2.5060208E7", "DELA CRUZ", "BTVTEd /MT", "MT 101WS", "3.0", "5.0"),
            G("2.5060208E7", "DELA CRUZ", "BTVTEd /MT", "NSTP 01", "", "DR"),           // alias of NSTP 01A, dropped
            G("2.5060208E7", "DELA CRUZ", "BTVTEd /MT", "GEC 112B ELEC3", "", "NA"),    // spacing differs; no grade yet
            G("2.5060208E7", "DELA CRUZ", "BTVTEd /MT", "MT 999", "", "2.0"),           // unknown subject
            G("2.5060209E7", "REYES", "BSIT", "IT 101A", "", "1.6.5"),                    // typo that can't be guessed
            G("", "NOID", "BSIT", "IT 101A", "", "2.0"),                                  // no Student ID
            G("2.1015251E7", "OLD", "BSIE /Digital Industrial Transformation", "IE 1", "", "2.0"), // program not offered
        }),
        ("2ND SEM_2024-2025", new[]
        {
            GradesHeader,
            G("2.4060001E7", "EARLIER", "BSIT", "IT 101A", "", "2.0"),          // only in 2024-2025 (e.g. graduated)
            G("2.5060209E7", "REYES", "BSIT", "IT 101A", "", "1.5"),            // a current student's older grade
            G("2.1015251E7", "OLD", "BSIE", "IE 1", "", "2.0"),                 // program no longer offered
        }));

    private MemoryStream StudentsFile() => Workbook(
        ("1st Sem_2026-2027", new[]
        {
            new[] { "STUDENT ID", "STUDENT NAME", "GENDER", "COURSE/Major", "YEAR", "STATUS", "", "SCHOLARSHIP" },
            new[] { "2.5060208E7", "DELA CRUZ, ANA MARIE SANTOS", "F", "BTVTED - MT", "2.0", "OLD", "IRREGULAR", "" },
            new[] { "2.606049E7", "ABAPO, NATHANIEL CANARECIO", "M", "BTVTED - MT", "1.0", "NEW", "REGULAR", "" },
            new[] { "STUDENT ID", "STUDENT NAME", "GENDER", "COURSE/Major", "YEAR", "STATUS", "", "" },   // repeated header
        }));

    private Task<Api.DTOs.Records.RecordsImportResultDto> Run(bool dryRun, bool withStudents = true, bool release = true) =>
        new RecordsImportService(_context).ImportAsync(GradesFile(), withStudents ? StudentsFile() : null, ["2025-2026"], dryRun, release, _registrar);

    // ── Small rules ────────────────────────────────────────────────────

    [Theory]
    [InlineData(".2.8", "2.8")]
    [InlineData("1..6", "1.6")]
    [InlineData("2,5", "2.5")]
    [InlineData("2.5.", "2.5")]
    [InlineData(" 1.75 ", "1.75")]
    [InlineData("1.6.5", null)]   // two possible readings: left as a problem
    [InlineData("2.8.0", null)]
    [InlineData("28", null)]      // 2.8 or 28%? not guessed
    [InlineData("5.5", null)]     // out of the scale
    [InlineData("abc", null)]
    public void FixGradeTypo_OnlyFixesObviousSlips(string raw, string? expected) =>
        Assert.Equal(expected == null ? null : decimal.Parse(expected, CultureInfo.InvariantCulture), RecordsImportService.FixGradeTypo(raw));

    [Fact]
    public async Task GradeWithTypingSlip_IsImported_AndListedInNotes()
    {
        var file = Workbook(("1ST SEM_2025-2026", new[]
        {
            GradesHeader,
            G("2.5060209E7", "REYES", "BSIT", "IT 101A", "", ".2.8"),
        }));
        var r = await new RecordsImportService(_context).ImportAsync(file, null, ["2025-2026"], true, true, _registrar);

        Assert.Equal(1, r.GradesPassed);
        Assert.Equal(0, r.TotalProblems);
        Assert.Contains(r.Notes, n => n.Contains("\".2.8\" read as 2.8"));
    }

    [Theory]
    [InlineData("1ST SEM_2025-2026", "2025-2026", 1)]
    [InlineData("2nd Sem_2024-2025", "2024-2025", 2)]
    [InlineData("SUMMER_2025-2026", "2025-2026", 3)]
    public void TermOfSheet_ReadsTheSheetName(string name, string year, int semester)
    {
        var t = RecordsImportService.TermOfSheet(name)!;
        Assert.Equal(year, t.SchoolYear);
        Assert.Equal(semester, t.Semester);
    }

    [Theory]
    [InlineData("BTVTEd /MT", "BTVTED-MT")]
    [InlineData("BSTE-MT", "BTVTED-MT")]
    [InlineData("BTVTEd /Mechanical Technology", "BTVTED-MT")]
    [InlineData("BTVTED - FT", "BTVTED-FT")]
    [InlineData("BTVTEd /Electrical Technology", "BTVTED-ET")]
    [InlineData("AB-ReEd & PasCom", "AB-REED")]
    [InlineData("BSME /Digital Manufacturing", "BSME")]
    [InlineData("BSME-MDM", "BSME")]
    [InlineData("BSIT", "BSIT")]
    public void ProgramCodeOf_TranslatesTheRegistrarsSpellings(string course, string code)
    {
        Assert.Equal(code, RecordsImportService.ProgramCodeOf(course));
    }

    [Fact]
    public void Codes_IgnoreSpacesAndDashes_AndNumbersReadFromExcel()
    {
        Assert.Equal(RecordsImportService.CodeKey("GEC 112B-Elec 3"), RecordsImportService.CodeKey("GEC 112B ELEC3"));
        Assert.Equal("25060208", XlsxReader.WholeNumberText("2.5060208E7"));
        Assert.Equal("8090037", XlsxReader.WholeNumberText("8090037.0"));
        Assert.Equal("Dela Cruz", RecordsImportService.NameCase("DELA CRUZ"));
        Assert.Equal("Juan Iii", RecordsImportService.NameCase("JUAN III").Replace("III", "Iii"));
    }

    [Fact]
    public void NotAnExcelFile_IsAClearError()
    {
        var ex = Assert.Throws<InvalidDataException>(() => XlsxReader.Read(new MemoryStream(Encoding.UTF8.GetBytes("a,b,c"))));
        Assert.Contains("Excel (.xlsx)", ex.Message);
    }

    // ── The import ─────────────────────────────────────────────────────

    [Fact]
    public async Task DryRun_ReportsEverything_AndSavesNothing()
    {
        var r = await Run(dryRun: true);

        Assert.Equal(new[] { "2025-2026", "2024-2025" }, r.SchoolYearsFound);
        Assert.Equal(new[] { "2025-2026" }, r.SchoolYearsImported);
        Assert.Equal(3, r.NewStudents);   // Dela Cruz, Reyes (grades), Abapo (students file only)
        Assert.Equal(1, r.GradesPassed);
        Assert.Equal(1, r.GradesFailed);
        Assert.Equal(1, r.Dropped);
        Assert.Equal(1, r.NoGradeYet);
        Assert.Contains("2025-2026 (1st Sem)", r.TermsCreated);
        Assert.Contains(r.Problems, p => p.Message.Contains("\"1.6.5\""));
        Assert.Contains(r.Problems, p => p.Message.Contains("No Student ID"));
        Assert.Contains(r.Problems, p => p.Message.Contains("Program BSIE is not in Setup"));
        Assert.Contains(r.Problems, p => p.Message.Contains("MT 999"));
        Assert.DoesNotContain(r.Problems, p => p.Message.Contains("\"STUDENT ID\""));   // repeated header is skipped quietly

        Assert.Equal(0, await _context.UserDetails.CountAsync());
        Assert.Equal(0, await _context.StudyLoads.CountAsync());
        Assert.Equal(1, await _context.AcademicTerms.CountAsync());
    }

    [Fact]
    public async Task Import_CreatesPendingStudents_WithTheirCurriculum_AndGrades()
    {
        await Run(dryRun: false);

        var ana = await _context.UserDetails.Include(u => u.User).SingleAsync(u => u.StudentID == "25060208");
        Assert.Equal("Dela Cruz", ana.Lastname);
        Assert.Equal("Ana Marie", ana.Firstname);
        Assert.Equal(1, ana.ProgramID);
        Assert.Equal(_mt2021, ana.CurriculumID);           // her grade codes are the 2021 ones
        Assert.Equal(2, ana.YearLevel);                     // from the students file (current)
        Assert.False(ana.IsRegular);
        Assert.StartsWith(RecordsImportService.PendingUidPrefix, ana.User!.FirebaseUID);
        Assert.Equal("", ana.User.Email);
        Assert.Equal(RoleUtils.Student, ana.User.Role);
        var personal = await _context.StudentPersonalDetails.SingleAsync(p => p.UserID == ana.UserID);
        Assert.Equal("Santos", personal.MiddleName);
        Assert.Equal("Female", personal.Sex);

        var loads = await _context.StudyLoads.Include(l => l.Class).ThenInclude(c => c!.Subject)
            .Where(l => l.UserID == ana.UserID).ToListAsync();
        Assert.Equal(4, loads.Count);
        Assert.Equal(StudyLoadStatus.Dropped, loads.Single(l => l.Class!.Subject!.SubjectCode == "NSTP 01A").LoadStatus);
        Assert.All(loads, l => Assert.Equal(RecordsImportService.ImportedClassName, l.Class!.ClassName));
        var grades = await _context.Grades.Where(g => loads.Select(l => l.StudyLoadID).Contains(g.StudyLoadID)).ToListAsync();
        Assert.Equal(2, grades.Count);   // NA and DR have no grade
        Assert.Contains(grades, g => g.FinalGrade == 1.5m && g.MidtermGrade == 1.7m && g.Remarks == 1);
        Assert.Contains(grades, g => g.FinalGrade == 5.0m && g.Remarks == 2);
        Assert.All(grades, g => Assert.Equal(_registrar, g.SubmittedByUserID));

        // Released, so Ana counts as cleared for 2025-2026 1st Sem (needed to enroll online).
        var term = await _context.AcademicTerms.SingleAsync(t => t.SchoolYear == "2025-2026" && t.Semester == 1);
        Assert.True((await _context.GradeClearances.SingleAsync(c => c.UserID == ana.UserID && c.TermID == term.TermID)).IsCleared);

        // A freshman only in the students file: batch 2026 from the ID, so the new curriculum; names kept together.
        var abapo = await _context.UserDetails.SingleAsync(u => u.StudentID == "26060490");
        Assert.Equal(_mt2026, abapo.CurriculumID);
        Assert.Equal("Abapo", abapo.Lastname);
        Assert.Equal("Nathaniel Canarecio", abapo.Firstname);
        Assert.True(abapo.IsRegular);

        // Only 2025-2026 was chosen: the 2024-2025 student was not imported.
        Assert.False(await _context.UserDetails.AnyAsync(u => u.StudentID == "24060001"));
    }

    [Fact]
    public async Task ImportingTwice_AddsNothingNew()
    {
        await Run(dryRun: false);
        var loads = await _context.StudyLoads.CountAsync();

        var again = await Run(dryRun: false);

        Assert.Equal(0, again.NewStudents);
        Assert.Equal(3, again.ExistingStudents);
        Assert.Equal(4, again.AlreadyImported);
        Assert.Equal(loads, await _context.StudyLoads.CountAsync());
        Assert.Equal(1, await _context.AcademicTerms.CountAsync(t => t.SchoolYear == "2025-2026" && t.Semester == 1));
    }

    [Fact]
    public async Task ExistingStudent_IsMatchedByStudentId_AndKeepsTheirDetails()
    {
        var id = Guid.NewGuid();
        _context.Users.Add(new User { UserID = id, FirebaseUID = "real", Email = "ana@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(), UserID = id, Firstname = "Ana", Lastname = "Cruz", StudentID = "25060208",
            ProgramID = 1, CurriculumID = _mt2021, YearLevel = 1
        });
        await _context.SaveChangesAsync();

        var r = await Run(dryRun: false, withStudents: false);

        Assert.Equal(1, r.ExistingStudents);
        var ana = await _context.UserDetails.SingleAsync(u => u.StudentID == "25060208");
        Assert.Equal("Cruz", ana.Lastname);
        Assert.Equal(1, ana.YearLevel);
        Assert.Equal(4, await _context.StudyLoads.CountAsync(l => l.UserID == id));
    }

    [Fact]
    public async Task OlderYears_OnlyExistingStudents_AddsTheirGrades_AndCreatesNobody()
    {
        await Run(dryRun: false);   // 2025-2026 first: Dela Cruz, Reyes and Abapo are now in the system
        var students = await _context.UserDetails.CountAsync();

        var r = await new RecordsImportService(_context).ImportAsync(GradesFile(), null, ["2024-2025"],
            dryRun: false, releaseGrades: true, _registrar, onlyExistingStudents: true);

        Assert.True(r.OnlyExistingStudents);
        Assert.Equal(0, r.NewStudents);
        Assert.Equal(2, r.StudentsNotInSystem);                 // the 2024-2025-only student and the BSIE one
        Assert.Equal(1, r.GradesPassed);
        Assert.DoesNotContain(r.Problems, p => p.Message.Contains("BSIE"));   // not in the system, so not a problem
        Assert.Equal(students, await _context.UserDetails.CountAsync());
        Assert.False(await _context.UserDetails.AnyAsync(u => u.StudentID == "24060001"));

        var reyes = await _context.UserDetails.SingleAsync(u => u.StudentID == "25060209");
        var load = await _context.StudyLoads.Include(l => l.Class).ThenInclude(c => c!.Term)
            .SingleAsync(l => l.UserID == reyes.UserID);
        Assert.Equal("2024-2025", load.Class!.Term!.SchoolYear);
        Assert.Equal(2, load.Class.Term.Semester);
        Assert.Equal(1.5m, (await _context.Grades.SingleAsync(g => g.StudyLoadID == load.StudyLoadID)).FinalGrade);
    }

    [Fact]
    public async Task OlderYears_WithoutTheOption_WouldCreateThoseStudents()
    {
        var r = await new RecordsImportService(_context).ImportAsync(GradesFile(), null, ["2024-2025"],
            dryRun: true, releaseGrades: true, _registrar);
        Assert.Equal(2, r.NewStudents);   // Earlier and Reyes; BSIE is reported as not in Setup
        Assert.Contains(r.Problems, p => p.Message.Contains("BSIE"));
    }

    [Fact]
    public async Task WithoutReleasing_NoClearanceIsGiven()
    {
        await Run(dryRun: false, release: false);
        Assert.Equal(0, await _context.GradeClearances.CountAsync());
    }

    [Fact]
    public async Task Controller_NoFile_IsABadRequest_AndLogsAfterImport()
    {
        var controller = new RecordsImportController(new RecordsImportService(_context));
        var http = new DefaultHttpContext();
        http.Items["user_id"] = _registrar;
        http.Items["role"] = RoleUtils.Registrar;
        http.Request.ContentType = "multipart/form-data; boundary=x";
        http.Request.Form = new FormCollection(new() { ["schoolYears"] = "2025-2026" }, new FormFileCollection());
        controller.ControllerContext = new ControllerContext { HttpContext = http };

        var bad = Assert.IsType<BadRequestObjectResult>(await controller.ImportRecords());
        Assert.Contains("grades Excel file", bad.Value!.ToString());

        var bytes = GradesFile().ToArray();
        var files = new FormFileCollection { new FormFile(new MemoryStream(bytes), 0, bytes.Length, "gradesFile", "GRADES.xlsx") };
        http.Request.Form = new FormCollection(new() { ["schoolYears"] = "2025-2026", ["dryRun"] = "false" }, files);
        var ok = Assert.IsType<OkObjectResult>(await controller.ImportRecords());
        Assert.Equal(2, ((Api.DTOs.Records.RecordsImportResultDto)ok.Value!).NewStudents);
    }

    // ── School email of a pending (imported) student ───────────────────

    private StudentsController Students()
    {
        var c = new StudentsController(_context, new UserDetailsRepository(_context));
        var http = new DefaultHttpContext();
        http.Items["user_id"] = _registrar;
        http.Items["role"] = RoleUtils.Registrar;
        http.RequestServices = Microsoft.Extensions.DependencyInjection.ServiceCollectionContainerBuilderExtensions.BuildServiceProvider(new Microsoft.Extensions.DependencyInjection.ServiceCollection());
        c.ControllerContext = new ControllerContext { HttpContext = http };
        return c;
    }

    [Fact]
    public async Task SchoolEmail_CanBeSet_WhileTheStudentHasNotSignedIn()
    {
        await Run(dryRun: false);
        var ana = await _context.UserDetails.SingleAsync(u => u.StudentID == "25060208");

        Assert.IsType<BadRequestObjectResult>(await Students().SetSchoolEmail(ana.UserID, new SetSchoolEmailDto { SchoolEmail = "ana@gmail.com" }));
        Assert.IsType<OkObjectResult>(await Students().SetSchoolEmail(ana.UserID, new SetSchoolEmailDto { SchoolEmail = " Ana.DelaCruz@dbtc-cebu.edu.ph " }));
        Assert.Equal("ana.delacruz@dbtc-cebu.edu.ph", (await _context.Users.SingleAsync(u => u.UserID == ana.UserID)).Email);

        // Someone else can't get the same email.
        var abapo = await _context.UserDetails.SingleAsync(u => u.StudentID == "26060490");
        var conflict = Assert.IsType<ConflictObjectResult>(await Students().SetSchoolEmail(abapo.UserID,
            new SetSchoolEmailDto { SchoolEmail = "ana.delacruz@dbtc-cebu.edu.ph" }));
        Assert.Contains("already belongs to Ana Marie Dela Cruz", conflict.Value!.ToString());
    }

    [Fact]
    public async Task StudentSearch_ShowsWhoHasNotSignedInYet()
    {
        await Run(dryRun: false);
        var ok = Assert.IsType<OkObjectResult>(await Students().Search("25060208", null, null));
        var row = Assert.Single(Assert.IsAssignableFrom<IEnumerable<Api.DTOs.Enrollment.StudentSearchResultDto>>(ok.Value));
        Assert.False(row.HasSignedIn);
        Assert.Equal("", row.Email);
    }

    [Fact]
    public async Task SchoolEmail_AfterSignIn_CannotBeChangedHere()
    {
        var id = Guid.NewGuid();
        _context.Users.Add(new User { UserID = id, FirebaseUID = "real-uid", Email = "x@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        await _context.SaveChangesAsync();

        var result = Assert.IsType<ConflictObjectResult>(await Students().SetSchoolEmail(id, new SetSchoolEmailDto { SchoolEmail = "y@dbtc-cebu.edu.ph" }));
        Assert.Contains("already signed in", result.Value!.ToString());
    }
}
