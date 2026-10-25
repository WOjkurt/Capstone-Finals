using System.Reflection;
using System.Text;
using Api.Auth;
using Api.Constants;
using Api.Controllers;
using Api.Data;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Curriculum;
using Api.DTOs.Setup;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

public class CurriculumImportTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly CurriculumImportService _service;
    private readonly CurriculumController _controller;
    private readonly UserRepository _userRepo;
    private readonly AcademicProgram _bsitProgram;
    private readonly Guid _registrarId = Guid.NewGuid();
    private readonly Guid _adminId = Guid.NewGuid();

    // Small valid 10-row fixture CSV
    private const string ValidFixtureCsv =
@"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
BSIT,IT 101,Introduction to Computing,3,3,0,3,0,1,1,,,
BSIT,IT 102,Computer Programming 1 (Lec),2,2,0,2,0,1,1,,IT 102L,
BSIT,IT 102L,Computer Programming 1 (Lab),1,0,1,0,3,1,1,,IT 102,
BSIT,IT 103,Discrete Mathematics,3,3,0,3,0,1,1,,,
BSIT,IT 104,Computer Programming 2,3,2,1,2,3,1,2,IT 102;IT 102L,,
BSIT,IT 201,""Data Structures, Algorithms and Analysis"",3,2,1,2,3,2,1,IT 104,,
BSIT,IT 202,Database Systems,3,2,1,2,3,2,1,IT 104,,
BSIT,IT 203,Object-Oriented Programming,3,2,1,2,3,2,2,IT 201,,
BSIT,IT 301,Integrative Programming and Technologies,3,2,1,2,3,3,1,IT 203,,3
BSIT,IT 302,Systems Administration and Maintenance,3,2,1,2,3,3,1,IT 202,,,
";

    public CurriculumImportTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _userRepo = new UserRepository(_context);
        _service = new CurriculumImportService(_context);
        _controller = new CurriculumController(_service, NullLogger<CurriculumController>.Instance);

        _bsitProgram = new AcademicProgram
        {
            ProgramID = 1,
            ProgramCode = "BSIT",
            ProgramName = "Bachelor of Science in Information Technology"
        };
        _context.AcademicPrograms.Add(_bsitProgram);

        var bsbaProgram = new AcademicProgram
        {
            ProgramID = 2,
            ProgramCode = "BSBA",
            ProgramName = "Bachelor of Science in Business Administration"
        };
        _context.AcademicPrograms.Add(bsbaProgram);

        _context.Users.AddRange(
            new User { UserID = _registrarId, FirebaseUID = "fb-reg", Email = "reg@test.edu", Role = RoleUtils.Registrar, IsActive = true },
            new User { UserID = _adminId, FirebaseUID = "fb-adm", Email = "adm@test.edu", Role = RoleUtils.Admin, IsActive = true }
        );

        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private static MemoryStream MakeStream(string content, bool withBom = false)
    {
        byte[] bytes;
        if (withBom)
        {
            var bom = new byte[] { 0xEF, 0xBB, 0xBF };
            var textBytes = Encoding.UTF8.GetBytes(content);
            bytes = new byte[bom.Length + textBytes.Length];
            Buffer.BlockCopy(bom, 0, bytes, 0, bom.Length);
            Buffer.BlockCopy(textBytes, 0, bytes, bom.Length, textBytes.Length);
        }
        else
        {
            bytes = Encoding.UTF8.GetBytes(content);
        }
        return new MemoryStream(bytes);
    }

    private void SetControllerContext(Guid userId, int role)
    {
        var http = new DefaultHttpContext();
        http.Items["user_id"] = userId;
        http.Items["role"] = role;
        _controller.ControllerContext = new ControllerContext { HttpContext = http };
    }

    // ── 1. Dry Run Writes Nothing & Counts Are Right ────────────────────────────

    [Fact]
    public async Task DryRun_WritesNothing_AndResponseCountsAreAccurate()
    {
        using var stream = MakeStream(ValidFixtureCsv);

        var result = await _service.ImportAsync(
            stream, "curriculum_bsit.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(result.DryRun);
        Assert.Equal("BSIT", result.Program);
        Assert.Equal(0, result.TotalErrors);
        Assert.Empty(result.Errors);

        // Subjects counts
        Assert.Equal(10, result.Subjects.Create);
        Assert.Equal(0, result.Subjects.Update);
        Assert.Equal(0, result.Subjects.Unchanged);

        // Requisites counts: IT 104 (2 prereqs), IT 201 (1 prereq), IT 202 (1 prereq), IT 203 (1 prereq), IT 301 (1 prereq), IT 302 (1 prereq) = 7 prereqs
        // Coreqs: IT 102 <-> IT 102L = 2 coreqs
        Assert.Equal(7, result.Requisites.PrerequisitesToAdd);
        Assert.Equal(2, result.Requisites.CorequisitesToAdd);
        Assert.Equal(0, result.Requisites.AlreadyExist);
        Assert.Equal(0, result.Requisites.ExtrasInDatabase);

        // Database must remain completely untouched
        Assert.Empty(await _context.Subjects.ToListAsync());
        Assert.Empty(await _context.SubjectPrerequisites.ToListAsync());
    }

    // ── 2. Apply Creates Subjects and Links, Second Apply is Idempotent ─────────

    [Fact]
    public async Task Apply_CreatesSubjectsAndLinks_AndSecondApplyIsIdempotent()
    {
        // First Apply
        using var stream1 = MakeStream(ValidFixtureCsv);
        var result1 = await _service.ImportAsync(
            stream1, "curriculum_bsit.csv", stream1.Length, dryRun: false, updateExisting: false, _registrarId);

        Assert.False(result1.DryRun);
        Assert.Equal(0, result1.TotalErrors);
        Assert.Equal(10, result1.Subjects.Create);
        Assert.Equal(7, result1.Requisites.PrerequisitesToAdd);
        Assert.Equal(2, result1.Requisites.CorequisitesToAdd);

        // Verify entities persisted
        var savedSubjects = await _context.Subjects.Where(s => s.ProgramID == _bsitProgram.ProgramID).ToListAsync();
        Assert.Equal(10, savedSubjects.Count);

        var savedRequisites = await _context.SubjectPrerequisites.ToListAsync();
        Assert.Equal(9, savedRequisites.Count); // 7 prereqs + 2 coreqs

        // Second Apply: Idempotent (0 creates)
        using var stream2 = MakeStream(ValidFixtureCsv);
        var result2 = await _service.ImportAsync(
            stream2, "curriculum_bsit.csv", stream2.Length, dryRun: false, updateExisting: false, _registrarId);

        Assert.False(result2.DryRun);
        Assert.Equal(0, result2.TotalErrors);
        Assert.Equal(0, result2.Subjects.Create); // ZERO creates
        Assert.Equal(10, result2.Subjects.Unchanged);
        Assert.Equal(0, result2.Subjects.Update);
        Assert.Equal(0, result2.Requisites.PrerequisitesToAdd);
        Assert.Equal(0, result2.Requisites.CorequisitesToAdd);
        Assert.Equal(9, result2.Requisites.AlreadyExist);
        Assert.Equal(0, result2.Requisites.ExtrasInDatabase);

        // Counts in DB remain unchanged
        Assert.Equal(10, await _context.Subjects.CountAsync());
        Assert.Equal(9, await _context.SubjectPrerequisites.CountAsync());
    }

    // ── 3. Quoted Title with Comma and UTF-8 BOM ────────────────────────────────

    [Fact]
    public async Task Import_QuotedTitleWithComma_AndFileWithBom_ParsesCorrectly()
    {
        using var stream = MakeStream(ValidFixtureCsv, withBom: true);
        var result = await _service.ImportAsync(
            stream, "curriculum_bsit.csv", stream.Length, dryRun: false, updateExisting: false, _registrarId);

        Assert.Equal(0, result.TotalErrors);

        var it201 = await _context.Subjects.FirstOrDefaultAsync(s => s.SubjectCode == "IT 201");
        Assert.NotNull(it201);
        Assert.Equal("Data Structures, Algorithms and Analysis", it201.SubjectTitle);
    }

    // ── 4. Error Cases ──────────────────────────────────────────────────────────

    [Fact]
    public async Task Error_UnknownProgram_ReturnsErrorWithKnownPrograms()
    {
        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
UNKNOWN,IT 101,Intro,3,3,0,3,0,1,1,,,
";
        using var stream = MakeStream(csv);
        var result = await _service.ImportAsync(
            stream, "test.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(result.TotalErrors > 0);
        Assert.Contains(result.Errors, e => e.Message.Contains("Program 'UNKNOWN' does not exist") && e.Message.Contains("BSIT"));
    }

    [Fact]
    public async Task Error_UnitMismatch_ReturnsError()
    {
        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
BSIT,IT 101,Intro,4,2,1,2,3,1,1,,,
";
        using var stream = MakeStream(csv);
        var result = await _service.ImportAsync(
            stream, "test.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(result.TotalErrors > 0);
        Assert.Contains(result.Errors, e => e.Message.Contains("units (4) must equal lec_units (2) + lab_units (1)"));
    }

    [Fact]
    public async Task Error_DuplicateCodeInFile_ReturnsError()
    {
        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
BSIT,IT 101,Intro Part 1,3,3,0,3,0,1,1,,,
BSIT,IT 101,Intro Part 2,3,3,0,3,0,1,1,,,
";
        using var stream = MakeStream(csv);
        var result = await _service.ImportAsync(
            stream, "test.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(result.TotalErrors > 0);
        Assert.Contains(result.Errors, e => e.Message.Contains("Duplicate subject code 'IT 101' inside file"));
    }

    [Fact]
    public async Task Error_UnknownPrerequisiteCode_ReturnsError()
    {
        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
BSIT,IT 102,Prog 2,3,2,1,2,3,1,2,IT 999,,
";
        using var stream = MakeStream(csv);
        var result = await _service.ImportAsync(
            stream, "test.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(result.TotalErrors > 0);
        Assert.Contains(result.Errors, e => e.Message.Contains("Prerequisite 'IT 999' does not exist"));
    }

    [Fact]
    public async Task Error_SelfLink_ReturnsError()
    {
        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
BSIT,IT 101,Intro,3,3,0,3,0,1,1,IT 101,,
";
        using var stream = MakeStream(csv);
        var result = await _service.ImportAsync(
            stream, "test.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(result.TotalErrors > 0);
        Assert.Contains(result.Errors, e => e.Message.Contains("cannot have itself as a prerequisite"));
    }

    [Fact]
    public async Task Error_PrerequisiteCycle_ReturnsError()
    {
        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
BSIT,IT 101,Course 1,3,3,0,3,0,1,1,IT 102,,
BSIT,IT 102,Course 2,3,3,0,3,0,1,2,IT 101,,
";
        using var stream = MakeStream(csv);
        var result = await _service.ImportAsync(
            stream, "test.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(result.TotalErrors > 0);
        Assert.Contains(result.Errors, e => e.Message.Contains("Circular prerequisite detected"));
    }

    [Fact]
    public async Task Error_BadYearSemesterStanding_ReturnsErrors()
    {
        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
BSIT,IT 101,Course 1,3,3,0,3,0,5,4,,,-1
";
        using var stream = MakeStream(csv);
        var result = await _service.ImportAsync(
            stream, "test.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(result.TotalErrors >= 3);
        Assert.Contains(result.Errors, e => e.Message.Contains("year must be between 1 and 4"));
        Assert.Contains(result.Errors, e => e.Message.Contains("semester must be between 1 and 3"));
        Assert.Contains(result.Errors, e => e.Message.Contains("standing_year must be between 1 and 4"));
    }

    [Fact]
    public async Task Error_MissingHeader_ReturnsError()
    {
        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester
BSIT,IT 101,Intro,3,3,0,3,0,1,1
";
        using var stream = MakeStream(csv);
        var result = await _service.ImportAsync(
            stream, "test.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(result.TotalErrors > 0);
        Assert.Contains(result.Errors, e => e.Message.Contains("Missing required CSV header(s)"));
    }

    [Fact]
    public async Task Error_FileTooLarge_ReturnsError()
    {
        using var stream = MakeStream("dummy");
        var result = await _service.ImportAsync(
            stream, "large.csv", fileLength: 1024 * 1024 + 10, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(result.TotalErrors > 0);
        Assert.Contains(result.Errors, e => e.Message.Contains("exceeds maximum limit of 1 MB"));
    }

    // ── 5. Existing Subject: updateExisting Flag Behavior ───────────────────────

    [Fact]
    public async Task ExistingSubject_NotChangedWithoutUpdateExisting_ChangedWithIt()
    {
        // 1. Seed IT 101 with original values
        var existing = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = "IT 101",
            SubjectTitle = "Old Title",
            LecUnits = 2,
            LabUnits = 0,
            LecHours = 2,
            LabHours = 0,
            ProgramID = _bsitProgram.ProgramID,
            YearLevel = 1,
            DefaultSemester = 1
        };
        _context.Subjects.Add(existing);
        await _context.SaveChangesAsync();

        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
BSIT,IT 101,Updated Title,3,3,0,3,0,1,1,,,
";

        // 2. Run with updateExisting = false
        using var stream1 = MakeStream(csv);
        var result1 = await _service.ImportAsync(
            stream1, "test.csv", stream1.Length, dryRun: false, updateExisting: false, _registrarId);

        Assert.Equal(0, result1.TotalErrors);
        Assert.Equal(0, result1.Subjects.Create);
        Assert.Equal(1, result1.Subjects.Update);
        Assert.Equal(0, result1.Subjects.Unchanged);
        Assert.Contains(result1.Warnings, w => w.Message.Contains("Pass updateExisting=true to update"));

        // Entity must NOT be updated
        var notUpdated = await _context.Subjects.FirstAsync(s => s.SubjectID == existing.SubjectID);
        Assert.Equal("Old Title", notUpdated.SubjectTitle);
        Assert.Equal(2, notUpdated.LecUnits);

        // 3. Run with updateExisting = true
        using var stream2 = MakeStream(csv);
        var result2 = await _service.ImportAsync(
            stream2, "test.csv", stream2.Length, dryRun: false, updateExisting: true, _registrarId);

        Assert.Equal(0, result2.TotalErrors);
        Assert.Equal(1, result2.Subjects.Update);

        // Entity IS updated
        var updated = await _context.Subjects.FirstAsync(s => s.SubjectID == existing.SubjectID);
        Assert.Equal("Updated Title", updated.SubjectTitle);
        Assert.Equal(3, updated.LecUnits);
    }

    // ── 6. All or Nothing: Failed Apply Leaves Database Unchanged ───────────────

    [Fact]
    public async Task FailedApply_LeavesDatabaseUnchanged()
    {
        var csvWithErrors = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
BSIT,IT 101,Intro,3,3,0,3,0,1,1,,,
BSIT,IT 102,Bad Subject,4,1,1,1,3,1,1,,,
"; // Row 2 has units 4 != 1+1 (error!)

        using var stream = MakeStream(csvWithErrors);
        var result = await _service.ImportAsync(
            stream, "curriculum.csv", stream.Length, dryRun: false, updateExisting: false, _registrarId);

        Assert.True(result.TotalErrors > 0);

        // Ensure IT 101 was NOT created
        var subjectsInDb = await _context.Subjects.ToListAsync();
        Assert.Empty(subjectsInDb);
    }

    // ── 7. Requisite Cycle Rule Agreement Test ──────────────────────────────────

    [Fact]
    public async Task RequisiteCycleDetection_AgreesWithSubjectService()
    {
        // 1. Seed two subjects IT 101 and IT 102
        var s1 = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = "IT 101",
            SubjectTitle = "Prog 1",
            LecUnits = 3,
            LabUnits = 0,
            LecHours = 3,
            LabHours = 0,
            ProgramID = _bsitProgram.ProgramID,
            YearLevel = 1,
            DefaultSemester = 1
        };
        var s2 = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = "IT 102",
            SubjectTitle = "Prog 2",
            LecUnits = 3,
            LabUnits = 0,
            LecHours = 3,
            LabHours = 0,
            ProgramID = _bsitProgram.ProgramID,
            YearLevel = 1,
            DefaultSemester = 2
        };
        _context.Subjects.AddRange(s1, s2);

        // Existing link: IT 102 requires IT 101
        var prereq = new SubjectPrerequisite
        {
            PrerequisiteID = Guid.NewGuid(),
            SubjectID = s2.SubjectID,
            PrerequisiteSubjectID = s1.SubjectID,
            RequisiteType = RequisiteTypeConstants.Prerequisite
        };
        _context.SubjectPrerequisites.Add(prereq);
        await _context.SaveChangesAsync();

        // Check SubjectService: trying to add IT 101 -> IT 102 throws InvalidOperationException (circular)
        var subjectRepo = new SubjectRepository(_context);
        var prereqRepo = new SubjectPrerequisiteRepository(_context);
        var programRepo = new AcademicProgramRepository(_context);
        var subjectService = new SubjectService(_context, subjectRepo, prereqRepo, programRepo);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            subjectService.AddPrerequisiteAsync(new CreatePrerequisiteDto
            {
                SubjectID = s1.SubjectID,
                PrerequisiteSubjectID = s2.SubjectID,
                RequisiteType = RequisiteTypeConstants.Prerequisite
            }));
        Assert.Contains("Circular prerequisite detected", ex.Message);

        // Check CurriculumImportService: CSV with IT 101 requiring IT 102 flags the exact same cycle error
        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
BSIT,IT 101,Prog 1,3,3,0,3,0,1,1,IT 102,,
";
        using var stream = MakeStream(csv);
        var importResult = await _service.ImportAsync(
            stream, "cycle.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        Assert.True(importResult.TotalErrors > 0);
        Assert.Contains(importResult.Errors, e => e.Message.Contains("Circular prerequisite detected"));
    }

    // ── 8. Controller Endpoint and Role Attribute Reflection Checks ─────────────

    [Fact]
    public void CurriculumController_HasRequireRegistrarOrAdminAttribute()
    {
        var actionMethod = typeof(CurriculumController).GetMethod(nameof(CurriculumController.Import));
        Assert.NotNull(actionMethod);

        var hasFilter = actionMethod.GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), true).Length > 0 ||
                        typeof(CurriculumController).GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), true).Length > 0;

        Assert.True(hasFilter, "CurriculumController.Import must be protected by [RequireRegistrarOrAdmin]");
    }

    [Fact]
    public async Task RequireRegistrarOrAdmin_CurriculumEndpoint_RejectsNonRegistrarOrAdmin()
    {
        var filter = new RequireRegistrarOrAdminAttribute();

        var tch = new User { UserID = Guid.NewGuid(), FirebaseUID = "fb-tch", Email = "t@dbtc.edu", Role = RoleUtils.Teacher, IsActive = true };
        var ph = new User { UserID = Guid.NewGuid(), FirebaseUID = "fb-ph", Email = "ph@dbtc.edu", Role = RoleUtils.ProgramHead, IsActive = true };
        var ch = new User { UserID = Guid.NewGuid(), FirebaseUID = "fb-ch", Email = "ch@dbtc.edu", Role = RoleUtils.CollegeHead, IsActive = true };
        var stu = new User { UserID = Guid.NewGuid(), FirebaseUID = "fb-stu", Email = "s@dbtc.edu", Role = RoleUtils.Student, IsActive = true };
        _context.Users.AddRange(tch, ph, ch, stu);
        await _context.SaveChangesAsync();

        foreach (var user in new[] { tch, ph, ch, stu })
        {
            var httpContext = new DefaultHttpContext();
            httpContext.Items["user_id"] = user.UserID;

            var serviceProvider = new Mock<IServiceProvider>();
            serviceProvider.Setup(sp => sp.GetService(typeof(IUserRepository))).Returns(_userRepo);
            httpContext.RequestServices = serviceProvider.Object;

            var actionContext = new ActionContext(httpContext, new RouteData(), new ActionDescriptor());
            var context = new ActionExecutingContext(actionContext, new List<IFilterMetadata>(), new Dictionary<string, object?>(), controller: null!);

            bool executed = false;
            await filter.OnActionExecutionAsync(context, () => { executed = true; return Task.FromResult<ActionExecutedContext>(null!); });

            Assert.False(executed);
            var objResult = Assert.IsType<ObjectResult>(context.Result);
            Assert.Equal(StatusCodes.Status403Forbidden, objResult.StatusCode);
        }
    }

    [Fact]
    public async Task RequireRegistrarOrAdmin_CurriculumEndpoint_AllowsRegistrarAndAdmin()
    {
        var filter = new RequireRegistrarOrAdminAttribute();

        foreach (var userId in new[] { _registrarId, _adminId })
        {
            var httpContext = new DefaultHttpContext();
            httpContext.Items["user_id"] = userId;

            var serviceProvider = new Mock<IServiceProvider>();
            serviceProvider.Setup(sp => sp.GetService(typeof(IUserRepository))).Returns(_userRepo);
            httpContext.RequestServices = serviceProvider.Object;

            var actionContext = new ActionContext(httpContext, new RouteData(), new ActionDescriptor());
            var context = new ActionExecutingContext(actionContext, new List<IFilterMetadata>(), new Dictionary<string, object?>(), controller: null!);

            bool executed = false;
            await filter.OnActionExecutionAsync(context, () => { executed = true; return Task.FromResult<ActionExecutedContext>(null!); });

            Assert.True(executed);
            Assert.Null(context.Result);
        }
    }

    [Fact]
    public async Task ControllerImport_NullFile_Returns400WithExpectedShape()
    {
        SetControllerContext(_registrarId, RoleUtils.Registrar);

        var result = await _controller.Import(file: null, dryRun: true, updateExisting: false);
        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(400, badRequest.StatusCode);

        var dto = Assert.IsType<CurriculumImportResponseDto>(badRequest.Value);
        Assert.True(dto.TotalErrors > 0);
        Assert.Contains(dto.Errors, e => e.Message.Contains("non-empty CSV file is required"));
    }

    // ── 9. Zero Data Rows and Program Case/Space Insensitivity ────────────────

    [Fact]
    public async Task Import_HeaderPresentButZeroDataRows_ReturnsNoErrorsAndZeroCounts()
    {
        // File has a valid header row but no data rows.
        var csv = "program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year\n";

        using var stream = MakeStream(csv);
        var result = await _service.ImportAsync(
            stream, "empty.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        // No validation errors — an empty import is not an error.
        Assert.Equal(0, result.TotalErrors);
        Assert.Empty(result.Errors);

        // All counts must be zero.
        Assert.Equal(0, result.Subjects.Create);
        Assert.Equal(0, result.Subjects.Update);
        Assert.Equal(0, result.Subjects.Unchanged);
        Assert.Equal(0, result.Requisites.PrerequisitesToAdd);
        Assert.Equal(0, result.Requisites.CorequisitesToAdd);

        // Nothing written to the database.
        Assert.Empty(await _context.Subjects.ToListAsync());
    }

    [Fact]
    public async Task Import_ProgramDiffersOnlyByCaseOrSpaces_IsAccepted()
    {
        // "bsit " (lower-case, trailing space) must resolve to the BSIT program.
        var csv = @"program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year
bsit ,IT 101,Introduction to Computing,3,3,0,3,0,1,1,,,
";
        using var stream = MakeStream(csv);
        var result = await _service.ImportAsync(
            stream, "test.csv", stream.Length, dryRun: true, updateExisting: false, _registrarId);

        // Must NOT produce a "Program does not exist" error.
        Assert.Equal(0, result.TotalErrors);
        Assert.Empty(result.Errors);

        // Must have resolved to the BSIT program record.
        Assert.Equal("BSIT", result.Program, ignoreCase: true);
        Assert.Equal(1, result.Subjects.Create);
    }

    [Fact]
    public async Task ControllerImport_ValidFile_Returns200WithExpectedShape()
    {
        SetControllerContext(_registrarId, RoleUtils.Registrar);

        var bytes = Encoding.UTF8.GetBytes(ValidFixtureCsv);
        var fileMock = new Mock<IFormFile>();
        fileMock.Setup(f => f.FileName).Returns("bsit_curriculum.csv");
        fileMock.Setup(f => f.Length).Returns(bytes.Length);
        fileMock.Setup(f => f.OpenReadStream()).Returns(new MemoryStream(bytes));

        var result = await _controller.Import(fileMock.Object, dryRun: true, updateExisting: false);
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(200, okResult.StatusCode);

        var dto = Assert.IsType<CurriculumImportResponseDto>(okResult.Value);
        Assert.True(dto.DryRun);
        Assert.Equal("BSIT", dto.Program);
        Assert.Equal(10, dto.Subjects.Create);
    }
}
