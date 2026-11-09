using Api.DTOs.Records;
using Api.Auth;
using Api.Common;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Enrollment;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

public class LrnBackendTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly UserDetailsRepository _userDetailsRepo;
    private readonly UserRepository _userRepo;
    private readonly EnrollmentApplicationRepository _appRepo;
    private readonly EnrollmentFormRepository _formRepo;
    private readonly EnrollmentResponseRepository _responseRepo;
    private readonly ContactRepository _contactRepo;
    private readonly EnrollmentService _enrollmentService;
    private readonly UserDetailsController _userDetailsController;
    private readonly StudentsController _studentsController;
    private readonly StudyLoadRepository _studyLoadRepo;
    private readonly StudyLoadService _studyLoadService;

    public LrnBackendTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _userDetailsRepo = new UserDetailsRepository(_context);
        _userRepo = new UserRepository(_context);
        _appRepo = new EnrollmentApplicationRepository(_context);
        _formRepo = new EnrollmentFormRepository(_context);
        _responseRepo = new EnrollmentResponseRepository(_context);
        _contactRepo = new ContactRepository(_context);

        var scopingMock = new Mock<IProgramScopingService>();
        _enrollmentService = new EnrollmentService(
            _context,
            _responseRepo,
            _appRepo,
            _formRepo,
            _contactRepo,
            _userDetailsRepo,
            _userRepo,
            NullLogger<EnrollmentService>.Instance);

        _userDetailsController = new UserDetailsController(
            _userDetailsRepo,
            scopingMock.Object,
            NullLogger<UserDetailsController>.Instance);

        _studentsController = new StudentsController(_context, _userDetailsRepo);

        _studyLoadRepo = new StudyLoadRepository(_context);
        var clearanceServiceMock = new Mock<IGradeClearanceService>();
        _studyLoadService = new StudyLoadService(
            _context,
            _studyLoadRepo,
            clearanceServiceMock.Object,
            NullLogger<StudyLoadService>.Instance);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void SetControllerContext(ControllerBase controller, int role, Guid userId)
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Items["role"] = role;
        httpContext.Items["user_id"] = userId;
        controller.ControllerContext = new ControllerContext { HttpContext = httpContext };
    }

    // ── 1. LrnHelper Normalization Tests ──────────────────────────────────────────

    [Theory]
    [InlineData(" 123456789012 ", "123456789012")]
    [InlineData("123 456 789 012", "123456789012")]
    [InlineData("1234-5678-9012", "123456789012")]
    [InlineData(" 1234 - 5678 - 9012 ", "123456789012")]
    public void LrnHelper_Normalize_SpacesAndDashes_ReturnsNormalizedDigits(string input, string expected)
    {
        var result = LrnHelper.Normalize(input);
        Assert.True(result.IsValid);
        Assert.Equal(expected, result.Lrn);
        Assert.Null(result.ErrorMessage);
    }

    [Fact]
    public async Task LinkAccountAsync_NewStudent_GetsTheCurriculumOfTheirBatch()
    {
        // Term is 2025-2026 and the form says 1st year, so the batch is 2025: the 2025 curriculum, not the 2021 one.
        var (app, _) = await CreateTestApplicationAsync(status: 2, lrn: null);
        var old2021 = new Curriculum { CurriculumID = Guid.NewGuid(), ProgramID = 1, Name = "2021", EffectiveFromYear = 2021 };
        var new2025 = new Curriculum { CurriculumID = Guid.NewGuid(), ProgramID = 1, Name = "2025", EffectiveFromYear = 2025 };
        var later2027 = new Curriculum { CurriculumID = Guid.NewGuid(), ProgramID = 1, Name = "2027", EffectiveFromYear = 2027 };
        _context.Curricula.AddRange(old2021, new2025, later2027);
        await _context.SaveChangesAsync();
        var studentUser = await CreateTestUserAsync("batch2025@dbtc.edu.ph", RoleUtils.Student);

        await _enrollmentService.LinkAccountAsync(app.ApplicationID, studentUser.Email, Guid.NewGuid());

        var details = await _userDetailsRepo.GetByUserIdAsync(studentUser.UserID);
        Assert.Equal(new2025.CurriculumID, details!.CurriculumID);
    }

    [Fact]
    public async Task ShiftProgram_PutsTheStudentOnTheNewProgramsBatchCurriculum()
    {
        var (app, _) = await CreateTestApplicationAsync(status: 2, lrn: null);   // active term 2025-2026, program 1
        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 2, ProgramCode = "BSME", ProgramName = "ME" });
        var me2021 = new Curriculum { CurriculumID = Guid.NewGuid(), ProgramID = 2, Name = "ME 2021", EffectiveFromYear = 2021 };
        var me2025 = new Curriculum { CurriculumID = Guid.NewGuid(), ProgramID = 2, Name = "ME 2025", EffectiveFromYear = 2025 };
        _context.Curricula.AddRange(me2021, me2025);
        await _context.SaveChangesAsync();
        var studentUser = await CreateTestUserAsync("shift@dbtc.edu.ph", RoleUtils.Student);
        await _enrollmentService.LinkAccountAsync(app.ApplicationID, studentUser.Email, Guid.NewGuid());
        var details = await _context.UserDetails.FirstAsync(u => u.UserID == studentUser.UserID);
        details.YearLevel = 2;   // a 2nd year in 2025-2026 started in 2024
        await _context.SaveChangesAsync();

        await new StudentRecordService(_context).ShiftProgramAsync(studentUser.UserID, new ShiftProgramDto { ProgramId = 2, Reason = "Shift" });

        var after = await _context.UserDetails.AsNoTracking().FirstAsync(u => u.UserID == studentUser.UserID);
        Assert.Equal(2, after.ProgramID);
        Assert.Equal(me2021.CurriculumID, after.CurriculumID);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(" - - ")]
    public void LrnHelper_Normalize_EmptyOrWhitespace_ReturnsValidNull(string? input)
    {
        var result = LrnHelper.Normalize(input);
        Assert.True(result.IsValid);
        Assert.Null(result.Lrn);
        Assert.Null(result.ErrorMessage);
    }

    [Theory]
    [InlineData("12345678901A")]
    [InlineData("12345ABCD012")]
    [InlineData("LRN123456789")]
    public void LrnHelper_Normalize_Letters_ReturnsInvalid(string input)
    {
        var result = LrnHelper.Normalize(input);
        Assert.False(result.IsValid);
        Assert.Null(result.Lrn);
        Assert.Contains("digits only", result.ErrorMessage);
    }

    [Theory]
    [InlineData("12345")]
    [InlineData("12345678901")] // 11 digits
    public void LrnHelper_Normalize_TooShort_ReturnsInvalid(string input)
    {
        var result = LrnHelper.Normalize(input);
        Assert.False(result.IsValid);
        Assert.Null(result.Lrn);
        Assert.Contains("exactly 12 digits", result.ErrorMessage);
    }

    [Theory]
    [InlineData("1234567890123")] // 13 digits
    [InlineData("1234567890123456")]
    public void LrnHelper_Normalize_TooLong_ReturnsInvalid(string input)
    {
        var result = LrnHelper.Normalize(input);
        Assert.False(result.IsValid);
        Assert.Null(result.Lrn);
        Assert.Contains("exactly 12 digits", result.ErrorMessage);
    }

    // ── 2. LinkAccountAsync LRN Tests ─────────────────────────────────────────────

    [Fact]
    public async Task LinkAccountAsync_ValidLrnOnForm_CopiesToUserDetails()
    {
        var (app, form) = await CreateTestApplicationAsync(status: 2, lrn: "1234-5678-9012");
        var studentUser = await CreateTestUserAsync("student1@dbtc.edu.ph", RoleUtils.Student);

        var result = await _enrollmentService.LinkAccountAsync(app.ApplicationID, studentUser.Email, Guid.NewGuid());
        Assert.NotNull(result);

        var userDetails = await _userDetailsRepo.GetByUserIdAsync(studentUser.UserID);
        Assert.NotNull(userDetails);
        Assert.Equal("123456789012", userDetails.LRN);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("invalid-lrn")]
    public async Task LinkAccountAsync_EmptyOrInvalidLrnOnForm_LeavesUserDetailsLrnNullAndStillLinks(string? rawLrn)
    {
        var (app, form) = await CreateTestApplicationAsync(status: 2, lrn: rawLrn);
        var studentUser = await CreateTestUserAsync($"student_{Guid.NewGuid():N}@dbtc.edu.ph", RoleUtils.Student);

        var result = await _enrollmentService.LinkAccountAsync(app.ApplicationID, studentUser.Email, Guid.NewGuid());
        Assert.NotNull(result);

        var userDetails = await _userDetailsRepo.GetByUserIdAsync(studentUser.UserID);
        Assert.NotNull(userDetails);
        Assert.Null(userDetails.LRN);
    }

    [Fact]
    public async Task LinkAccountAsync_DuplicateLrnAssignedToAnotherStudent_ThrowsInvalidOperationExceptionAndDoesNotLink()
    {
        // First student has LRN 111122223333
        var existingUser = await CreateTestUserAsync("existing@dbtc.edu.ph", RoleUtils.Student);
        var existingDetails = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = existingUser.UserID,
            Firstname = "Existing",
            Lastname = "Student",
            LRN = "111122223333"
        };
        await _userDetailsRepo.AddAsync(existingDetails);

        // Second student tries to link with the same LRN
        var (app, form) = await CreateTestApplicationAsync(status: 2, lrn: "1111-2222-3333");
        var newUser = await CreateTestUserAsync("new@dbtc.edu.ph", RoleUtils.Student);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _enrollmentService.LinkAccountAsync(app.ApplicationID, newUser.Email, Guid.NewGuid()));

        Assert.Contains("This LRN is already assigned to another student", ex.Message);

        // Verification: UserDetails for newUser was NOT created
        var newDetails = await _userDetailsRepo.GetByUserIdAsync(newUser.UserID);
        Assert.Null(newDetails);
    }

    // ── 3. PATCH /api/userdetails/{userId}/lrn Endpoint Tests ─────────────────────

    [Fact]
    public async Task PatchUserDetailsLrn_RegistrarCaller_ValidLrn_UpdatesLrn()
    {
        var student = await CreateTestUserAsync("student_patch@dbtc.edu.ph", RoleUtils.Student);
        var details = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Juan",
            Lastname = "Dela Cruz",
            LRN = null
        };
        await _userDetailsRepo.AddAsync(details);

        var registrarId = Guid.NewGuid();
        SetControllerContext(_userDetailsController, RoleUtils.Registrar, registrarId);

        var result = await _userDetailsController.UpdateLrn(student.UserID, new UpdateLrnRequestDto { Lrn = "9876-5432-1098" });
        var okResult = Assert.IsType<OkObjectResult>(result);

        var updated = await _userDetailsRepo.GetByUserIdAsync(student.UserID);
        Assert.NotNull(updated);
        Assert.Equal("987654321098", updated.LRN);
    }

    [Fact]
    public async Task PatchUserDetailsLrn_EmptyOrNullLrn_ClearsLrn()
    {
        var student = await CreateTestUserAsync("student_clear@dbtc.edu.ph", RoleUtils.Student);
        var details = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Juan",
            Lastname = "Dela Cruz",
            LRN = "987654321098"
        };
        await _userDetailsRepo.AddAsync(details);

        SetControllerContext(_userDetailsController, RoleUtils.Registrar, Guid.NewGuid());

        var result = await _userDetailsController.UpdateLrn(student.UserID, new UpdateLrnRequestDto { Lrn = "" });
        Assert.IsType<OkObjectResult>(result);

        var updated = await _userDetailsRepo.GetByUserIdAsync(student.UserID);
        Assert.NotNull(updated);
        Assert.Null(updated.LRN);
    }

    [Fact]
    public async Task PatchUserDetailsLrn_NonStudentUser_ReturnsBadRequest()
    {
        var teacher = await CreateTestUserAsync("teacher@dbtc.edu.ph", RoleUtils.Teacher);
        var details = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = teacher.UserID,
            Firstname = "Sir",
            Lastname = "Teacher"
        };
        await _userDetailsRepo.AddAsync(details);

        SetControllerContext(_userDetailsController, RoleUtils.Registrar, Guid.NewGuid());

        var result = await _userDetailsController.UpdateLrn(teacher.UserID, new UpdateLrnRequestDto { Lrn = "123456789012" });
        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Contains("students", badRequest.Value?.ToString());
    }

    // ── Student IDs (DBTC IDs such as 25060208) ──────────────────────────────

    [Theory]
    [InlineData(" 25060208 ", "25060208")]
    [InlineData("2506-0208", "25060208")]
    [InlineData("08090037", "08090037")]   // leading zeros are kept
    [InlineData("8090037", "8090037")]     // older 7-digit numbers
    public void StudentID_Normalize_Valid(string raw, string expected)
    {
        var r = StudentIdHelper.Normalize(raw);
        Assert.True(r.IsValid);
        Assert.Equal(expected, r.Number);
    }

    [Theory]
    [InlineData("2.5060208E7")]
    [InlineData("ABC123")]
    [InlineData("123")]
    [InlineData("1234567890123456")]
    public void StudentID_Normalize_Invalid(string raw)
    {
        Assert.False(StudentIdHelper.Normalize(raw).IsValid);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("  ")]
    public void StudentID_Normalize_Empty_MeansNone(string? raw)
    {
        var r = StudentIdHelper.Normalize(raw);
        Assert.True(r.IsValid);
        Assert.Null(r.Number);
    }

    private async Task<User> StudentWithDetailsAsync(string email, string first, string? number = null)
    {
        var user = await CreateTestUserAsync(email, RoleUtils.Student);
        await _userDetailsRepo.AddAsync(new UserDetails
        {
            UserDetailID = Guid.NewGuid(), UserID = user.UserID, Firstname = first, Lastname = "Cruz", StudentID = number
        });
        return user;
    }

    [Fact]
    public async Task PatchStudentID_SetsAndClears()
    {
        var student = await StudentWithDetailsAsync("num1@dbtc.edu.ph", "Ana");
        SetControllerContext(_userDetailsController, RoleUtils.Registrar, Guid.NewGuid());

        Assert.IsType<OkObjectResult>(await _userDetailsController.UpdateStudentId(student.UserID,
            new UpdateStudentIdRequestDto { StudentID = " 2506 0208 " }));
        Assert.Equal("25060208", (await _context.UserDetails.AsNoTracking().FirstAsync(u => u.UserID == student.UserID)).StudentID);

        Assert.IsType<OkObjectResult>(await _userDetailsController.UpdateStudentId(student.UserID,
            new UpdateStudentIdRequestDto { StudentID = "" }));
        Assert.Null((await _context.UserDetails.AsNoTracking().FirstAsync(u => u.UserID == student.UserID)).StudentID);
    }

    [Fact]
    public async Task PatchStudentID_TakenByAnotherStudent_IsConflict()
    {
        await StudentWithDetailsAsync("num2@dbtc.edu.ph", "Ben", "25060208");
        var other = await StudentWithDetailsAsync("num3@dbtc.edu.ph", "Cara");
        SetControllerContext(_userDetailsController, RoleUtils.Registrar, Guid.NewGuid());

        var result = await _userDetailsController.UpdateStudentId(other.UserID,
            new UpdateStudentIdRequestDto { StudentID = "25060208" });
        var conflict = Assert.IsType<ConflictObjectResult>(result);
        Assert.Contains("already belongs to Ben Cruz", conflict.Value?.ToString());
    }

    [Fact]
    public async Task PatchStudentID_BadFormat_OrNotAStudent_IsRejected()
    {
        var student = await StudentWithDetailsAsync("num4@dbtc.edu.ph", "Dan");
        SetControllerContext(_userDetailsController, RoleUtils.Registrar, Guid.NewGuid());
        Assert.IsType<BadRequestObjectResult>(await _userDetailsController.UpdateStudentId(student.UserID,
            new UpdateStudentIdRequestDto { StudentID = "2.5060208E7" }));

        var teacher = await CreateTestUserAsync("teach-num@dbtc.edu.ph", RoleUtils.Teacher);
        await _userDetailsRepo.AddAsync(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = teacher.UserID, Firstname = "T", Lastname = "T" });
        Assert.IsType<NotFoundObjectResult>(await _userDetailsController.UpdateStudentId(teacher.UserID,
            new UpdateStudentIdRequestDto { StudentID = "25060208" }));
    }

    [Fact]
    public async Task StudentSearch_ByStudentID_FindsThatStudent()
    {
        await StudentWithDetailsAsync("num5@dbtc.edu.ph", "Eve", "25060208");
        await StudentWithDetailsAsync("num6@dbtc.edu.ph", "Fay", "25060209");
        SetControllerContext(_studentsController, RoleUtils.Registrar, Guid.NewGuid());

        var ok = Assert.IsType<OkObjectResult>(await _studentsController.Search("25060208", null, null));
        var list = Assert.IsAssignableFrom<IEnumerable<StudentSearchResultDto>>(ok.Value).ToList();
        Assert.Single(list);
        Assert.Equal("25060208", list[0].StudentID);
        Assert.Contains("Eve", list[0].FullName);
    }

    [Fact]
    public async Task PatchUserDetailsLrn_DuplicateLrn_ReturnsBadRequest()
    {
        var student1 = await CreateTestUserAsync("s1@dbtc.edu.ph", RoleUtils.Student);
        var details1 = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student1.UserID,
            Firstname = "Student",
            Lastname = "One",
            LRN = "111122223333"
        };
        await _userDetailsRepo.AddAsync(details1);

        var student2 = await CreateTestUserAsync("s2@dbtc.edu.ph", RoleUtils.Student);
        var details2 = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student2.UserID,
            Firstname = "Student",
            Lastname = "Two",
            LRN = null
        };
        await _userDetailsRepo.AddAsync(details2);

        SetControllerContext(_userDetailsController, RoleUtils.Registrar, Guid.NewGuid());

        var result = await _userDetailsController.UpdateLrn(student2.UserID, new UpdateLrnRequestDto { Lrn = "1111-2222-3333" });
        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Contains("already assigned to another student", badRequest.Value?.ToString());
    }

    [Fact]
    public async Task PatchUserDetailsLrn_InvalidLrn_ReturnsBadRequest()
    {
        var student = await CreateTestUserAsync("s_inv@dbtc.edu.ph", RoleUtils.Student);
        var details = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Student",
            Lastname = "Invalid"
        };
        await _userDetailsRepo.AddAsync(details);

        SetControllerContext(_userDetailsController, RoleUtils.Registrar, Guid.NewGuid());

        var result = await _userDetailsController.UpdateLrn(student.UserID, new UpdateLrnRequestDto { Lrn = "12345" });
        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Contains("12 digits", badRequest.Value?.ToString());
    }

    // ── 4. Students Search Endpoint Tests ─────────────────────────────────────────

    [Fact]
    public async Task StudentsSearch_ByExactLrn_ReturnsMatchingStudentWithHasLrnTrue()
    {
        var student = await CreateTestUserAsync("search_lrn@dbtc.edu.ph", RoleUtils.Student);
        var details = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Carlos",
            Lastname = "Yulo",
            LRN = "123456789012",
            ProgramID = 1,
            YearLevel = 2,
            StudentStatus = 1
        };
        await _userDetailsRepo.AddAsync(details);

        SetControllerContext(_studentsController, RoleUtils.Registrar, Guid.NewGuid());

        var result = await _studentsController.Search("1234-5678-9012", null, null);
        var okResult = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<List<StudentSearchResultDto>>(okResult.Value);

        Assert.Single(list);
        Assert.Equal("Carlos Yulo", list[0].FullName);
        Assert.Equal("123456789012", list[0].Lrn);
        Assert.True(list[0].HasLrn);
    }

    [Fact]
    public async Task StudentsSearch_ByNameOrEmail_ReturnsMatchingStudents()
    {
        var student = await CreateTestUserAsync("maria.clara@dbtc.edu.ph", RoleUtils.Student);
        var details = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Maria",
            Lastname = "Clara",
            LRN = null,
            ProgramID = 1
        };
        await _userDetailsRepo.AddAsync(details);

        SetControllerContext(_studentsController, RoleUtils.Registrar, Guid.NewGuid());

        var result = await _studentsController.Search("clara", null, null);
        var okResult = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<List<StudentSearchResultDto>>(okResult.Value);

        Assert.Single(list);
        Assert.Equal("Maria Clara", list[0].FullName);
        Assert.False(list[0].HasLrn);
    }

    [Fact]
    public async Task StudentsSearch_ByMissingLrnTrue_ReturnsOnlyStudentsWithoutLrn()
    {
        var s1 = await CreateTestUserAsync("with_lrn@dbtc.edu.ph", RoleUtils.Student);
        await _userDetailsRepo.AddAsync(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = s1.UserID,
            Firstname = "Has",
            Lastname = "Lrn",
            LRN = "111111111111"
        });

        var s2 = await CreateTestUserAsync("without_lrn@dbtc.edu.ph", RoleUtils.Student);
        await _userDetailsRepo.AddAsync(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = s2.UserID,
            Firstname = "No",
            Lastname = "Lrn",
            LRN = null
        });

        SetControllerContext(_studentsController, RoleUtils.Registrar, Guid.NewGuid());

        var result = await _studentsController.Search(null, missingLrn: true, null);
        var okResult = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<List<StudentSearchResultDto>>(okResult.Value);

        Assert.Contains(list, s => s.UserId == s2.UserID);
        Assert.DoesNotContain(list, s => s.UserId == s1.UserID);
    }

    [Fact]
    public async Task StudentsSearch_NonStudentRoles_NeverReturned()
    {
        var teacher = await CreateTestUserAsync("search_teacher@dbtc.edu.ph", RoleUtils.Teacher);
        await _userDetailsRepo.AddAsync(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = teacher.UserID,
            Firstname = "Sir",
            Lastname = "Searchable"
        });

        SetControllerContext(_studentsController, RoleUtils.Registrar, Guid.NewGuid());

        var result = await _studentsController.Search("Searchable", null, null);
        var okResult = Assert.IsType<OkObjectResult>(result);
        var list = Assert.IsAssignableFrom<List<StudentSearchResultDto>>(okResult.Value);

        Assert.Empty(list);
    }

    // ── 5. Task 6b StudyLoad HasLrn & Teacher Protection Tests ─────────────────────

    [Fact]
    public async Task StudyLoad_TeacherCaller_HasLrnAndLrnAreNull()
    {
        var student = await CreateTestUserAsync("roster_stud@dbtc.edu.ph", RoleUtils.Student);
        await _userDetailsRepo.AddAsync(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Roster",
            Lastname = "Student",
            LRN = "123456789012"
        });

        var term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = true };
        _context.AcademicTerms.Add(term);
        var subject = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT101", SubjectTitle = "Intro", ProgramID = 1 };
        _context.Subjects.Add(subject);
        var cls = new Class { ClassID = Guid.NewGuid(), ClassName = "IT 1A", TermID = term.TermID, SubjectID = subject.SubjectID };
        _context.Classes.Add(cls);

        var load = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = cls.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled
        };
        _context.StudyLoads.Add(load);
        await _context.SaveChangesAsync();

        // When excludePending is true, caller is Teacher
        var results = await _studyLoadService.GetByClassAsync(cls.ClassID, excludePending: true);
        Assert.Single(results);
        Assert.Null(results[0].HasLrn);
        Assert.Null(results[0].LRN);
    }

    [Fact]
    public async Task StudyLoad_NonTeacherStaff_HasLrnAndLrnArePopulated()
    {
        var student = await CreateTestUserAsync("staff_roster_stud@dbtc.edu.ph", RoleUtils.Student);
        await _userDetailsRepo.AddAsync(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Staff",
            Lastname = "RosterStudent",
            LRN = "123456789012"
        });

        var term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = true };
        _context.AcademicTerms.Add(term);
        var subject = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT102", SubjectTitle = "Intro 2", ProgramID = 1 };
        _context.Subjects.Add(subject);
        var cls = new Class { ClassID = Guid.NewGuid(), ClassName = "IT 1B", TermID = term.TermID, SubjectID = subject.SubjectID };
        _context.Classes.Add(cls);

        var load = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = cls.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled
        };
        _context.StudyLoads.Add(load);
        await _context.SaveChangesAsync();

        // When excludePending is false, caller is Registrar / Admin / Program Head / College Head
        var results = await _studyLoadService.GetByClassAsync(cls.ClassID, excludePending: false);
        Assert.Single(results);
        Assert.True(results[0].HasLrn);
        Assert.Equal("123456789012", results[0].LRN);
    }

    [Fact]
    public async Task StudyLoad_StudentViewingSelf_HasLrnIsPopulatedButLrnMasked()
    {
        var student = await CreateTestUserAsync("self_stud@dbtc.edu.ph", RoleUtils.Student);
        await _userDetailsRepo.AddAsync(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Self",
            Lastname = "Student",
            LRN = "123456789012"
        });

        var term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = true };
        _context.AcademicTerms.Add(term);
        var subject = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT103", SubjectTitle = "Intro 3", ProgramID = 1 };
        _context.Subjects.Add(subject);
        var cls = new Class { ClassID = Guid.NewGuid(), ClassName = "IT 1C", TermID = term.TermID, SubjectID = subject.SubjectID };
        _context.Classes.Add(cls);

        var load = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = cls.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled
        };
        _context.StudyLoads.Add(load);
        await _context.SaveChangesAsync();

        var results = await _studyLoadService.GetByStudentAsync(student.UserID, term.TermID, isStudentCaller: true);
        Assert.Single(results);
        Assert.True(results[0].HasLrn);
        Assert.Null(results[0].LRN);
    }

    [Theory]
    [InlineData(RoleUtils.Registrar, true, "123456789012")]
    [InlineData(RoleUtils.Admin, true, "123456789012")]
    [InlineData(RoleUtils.CollegeHead, true, "123456789012")]
    [InlineData(RoleUtils.ProgramHead, true, null)]
    [InlineData(RoleUtils.Student, true, null)]
    public async Task StudyLoad_GetByStudent_Roles_MaskLrnAppropriately(int role, bool expectedHasLrn, string? expectedLrn)
    {
        var student = await CreateTestUserAsync($"stud_{role}@dbtc.edu.ph", RoleUtils.Student);
        await _userDetailsRepo.AddAsync(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Student",
            Lastname = "RoleTest",
            LRN = "123456789012"
        });

        var term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = true };
        _context.AcademicTerms.Add(term);
        var subject = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = $"IT10_{role}", SubjectTitle = "Subject", ProgramID = 1 };
        _context.Subjects.Add(subject);
        var cls = new Class { ClassID = Guid.NewGuid(), ClassName = "IT 1X", TermID = term.TermID, SubjectID = subject.SubjectID };
        _context.Classes.Add(cls);

        var load = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = cls.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled
        };
        _context.StudyLoads.Add(load);
        await _context.SaveChangesAsync();

        var results = await _studyLoadService.GetByStudentAsync(student.UserID, term.TermID, isStudentCaller: role == RoleUtils.Student, callerRole: role);
        Assert.Single(results);
        Assert.Equal(expectedHasLrn, results[0].HasLrn);
        Assert.Equal(expectedLrn, results[0].LRN);
    }

    [Theory]
    [InlineData(RoleUtils.Registrar, true, "123456789012")]
    [InlineData(RoleUtils.Admin, true, "123456789012")]
    [InlineData(RoleUtils.CollegeHead, true, "123456789012")]
    [InlineData(RoleUtils.ProgramHead, true, null)]
    [InlineData(RoleUtils.Teacher, null, null)]
    public async Task StudyLoad_GetByClass_Roles_MaskLrnAppropriately(int role, bool? expectedHasLrn, string? expectedLrn)
    {
        var student = await CreateTestUserAsync($"cls_stud_{role}@dbtc.edu.ph", RoleUtils.Student);
        await _userDetailsRepo.AddAsync(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "ClassStudent",
            Lastname = "RoleTest",
            LRN = "123456789012"
        });

        var term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = true };
        _context.AcademicTerms.Add(term);
        var subject = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = $"CS10_{role}", SubjectTitle = "Subject", ProgramID = 1 };
        _context.Subjects.Add(subject);
        var cls = new Class { ClassID = Guid.NewGuid(), ClassName = "CS 1X", TermID = term.TermID, SubjectID = subject.SubjectID };
        _context.Classes.Add(cls);

        var load = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = cls.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled
        };
        _context.StudyLoads.Add(load);
        await _context.SaveChangesAsync();

        var results = await _studyLoadService.GetByClassAsync(cls.ClassID, excludePending: role == RoleUtils.Teacher, callerRole: role);
        Assert.Single(results);
        Assert.Equal(expectedHasLrn, results[0].HasLrn);
        Assert.Equal(expectedLrn, results[0].LRN);
    }

    [Fact]
    public async Task StudyLoad_NoLrn_NonTeacherHasFalse_TeacherHasNull()
    {
        var student = await CreateTestUserAsync("nolrn_stud@dbtc.edu.ph", RoleUtils.Student);
        await _userDetailsRepo.AddAsync(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "NoLrn",
            Lastname = "Student",
            LRN = null
        });

        var term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = true };
        _context.AcademicTerms.Add(term);
        var subject = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "NL101", SubjectTitle = "Subject", ProgramID = 1 };
        _context.Subjects.Add(subject);
        var cls = new Class { ClassID = Guid.NewGuid(), ClassName = "NL 1A", TermID = term.TermID, SubjectID = subject.SubjectID };
        _context.Classes.Add(cls);

        var load = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = cls.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled
        };
        _context.StudyLoads.Add(load);
        await _context.SaveChangesAsync();

        var regResults = await _studyLoadService.GetByClassAsync(cls.ClassID, excludePending: false, callerRole: RoleUtils.Registrar);
        Assert.False(regResults[0].HasLrn);
        Assert.Null(regResults[0].LRN);

        var teacherResults = await _studyLoadService.GetByClassAsync(cls.ClassID, excludePending: true, callerRole: RoleUtils.Teacher);
        Assert.Null(teacherResults[0].HasLrn);
        Assert.Null(teacherResults[0].LRN);
    }

    // ── 6. Application LRN Edit Endpoint ──────────────────────────────────────────

    [Theory]
    [InlineData(1)] // Pending
    [InlineData(2)] // Approved
    public async Task PatchApplicationLrn_PendingOrApproved_AllowsUpdate(int status)
    {
        var (app, form) = await CreateTestApplicationAsync(status: status, lrn: null);

        var updated = await _enrollmentService.UpdateApplicationLrnAsync(app.ApplicationID, " 5555 - 6666 - 7777 ");
        Assert.NotNull(updated);
        Assert.NotNull(updated.Form);
        Assert.Equal("555566667777", updated.Form.LRN);

        var refreshedForm = await _formRepo.GetByApplicationIdAsync(app.ApplicationID);
        Assert.NotNull(refreshedForm);
        Assert.Equal("555566667777", refreshedForm.LRN);
    }

    [Theory]
    [InlineData(4)] // Active
    [InlineData(3)] // Rejected
    public async Task PatchApplicationLrn_ActiveOrRejected_ThrowsInvalidOperationExceptionWithClearMessage(int status)
    {
        var (app, form) = await CreateTestApplicationAsync(status: status, lrn: null);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _enrollmentService.UpdateApplicationLrnAsync(app.ApplicationID, "123456789012"));

        Assert.Equal("LRN cannot be edited on an active or rejected application. Please edit the student's profile LRN instead.", ex.Message);
    }

    [Fact]
    public async Task PatchApplicationLrn_Controller_ActiveOrRejected_Returns400BadRequest()
    {
        var (activeApp, _) = await CreateTestApplicationAsync(status: 4, lrn: null);
        var controller = new EnrollmentApplicationsController(_enrollmentService);

        var result = await controller.UpdateLrn(activeApp.ApplicationID, new UpdateApplicationLrnDto { Lrn = "123456789012" });
        var badRequest = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(StatusCodes.Status400BadRequest, badRequest.StatusCode);
        Assert.Contains("edit the student's profile LRN instead", badRequest.Value?.ToString() ?? "");
    }

    [Fact]
    public async Task PatchApplicationLrn_InvalidLrn_ThrowsArgumentException()
    {
        var (app, form) = await CreateTestApplicationAsync(status: 1, lrn: null);

        var ex = await Assert.ThrowsAsync<ArgumentException>(
            () => _enrollmentService.UpdateApplicationLrnAsync(app.ApplicationID, "invalid-123"));
        Assert.Contains("digits only", ex.Message);
    }

    // ── Helper Methods ────────────────────────────────────────────────────────────

    private async Task<User> CreateTestUserAsync(string email, int role)
    {
        var user = new User
        {
            UserID = Guid.NewGuid(),
            Email = email,
            FirebaseUID = $"fb-{Guid.NewGuid():N}",
            Role = role,
            IsActive = true
        };
        await _userRepo.AddAsync(user);
        return user;
    }

    private async Task<(EnrollmentApplication App, EnrollmentForm Form)> CreateTestApplicationAsync(int status, string? lrn)
    {
        var term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = true };
        _context.AcademicTerms.Add(term);

        var program = await _context.AcademicPrograms.FindAsync(1);
        if (program == null)
        {
            _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "Information Technology" });
        }

        var response = new EnrollmentResponse
        {
            ResponseID = Guid.NewGuid(),
            EmailAddress = $"applicant-{Guid.NewGuid():N}@test.com",
            Timestamp = DateTime.UtcNow,
            IsProcessed = false
        };
        _context.EnrollmentResponses.Add(response);
        await _context.SaveChangesAsync();

        var app = new EnrollmentApplication
        {
            ApplicationID = Guid.NewGuid(),
            ResponseID = response.ResponseID,
            ProgramID = 1,
            TermID = term.TermID,
            Status = status,
            CreatedAt = DateTime.UtcNow
        };
        await _appRepo.AddAsync(app);

        var form = new EnrollmentForm
        {
            EnrollmentID = Guid.NewGuid(),
            ApplicationID = app.ApplicationID,
            FirstName = "Test",
            MiddleName = "M",
            LastName = "Applicant",
            Suffix = "",
            PlaceOfBirth = "Cebu",
            Sex = "Male",
            CivilStatus = "Single",
            Nationality = "Filipino",
            MobileNumber = "09123456789",
            Barangay = "Poblacion",
            CityMunicipality = "Cebu City",
            Province = "Cebu",
            ZipCode = "6000",
            LastSchoolAttended = "DBTC",
            SchoolAddress = "Punta Princesa",
            PreviousCollege = "N/A",
            PreviousCourse = "N/A",
            YearLevel = 1,
            LRN = lrn
        };
        await _formRepo.AddAsync(form);

        return (app, form);
    }
}
