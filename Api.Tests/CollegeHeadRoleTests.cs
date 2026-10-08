using Api.Auth;
using Api.Controllers;
using Api.Data;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Admin;
using Api.DTOs.Enrollment;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

public class CollegeHeadRoleTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly UserRepository _userRepo;
    private readonly UserDetailsRepository _userDetailsRepo;
    private readonly PositionRepository _posRepo;
    private readonly AcademicProgramRepository _progRepo;
    private readonly StudyLoadRepository _studyLoadRepo;
    private readonly ClassRepository _classRepo;
    private readonly SubjectRepository _subjectRepo;
    private readonly Mock<IProgramScopingService> _scopingMock;
    private readonly Mock<IGradeClearanceService> _clearanceMock;
    private readonly StudyLoadService _studyLoadService;
    private readonly UserDetailsController _userDetailsController;
    private readonly StudentsController _studentsController;
    private readonly StudyLoadsController _studyLoadsController;

    private readonly AcademicProgram _program1;
    private readonly AcademicProgram _program2;
    private readonly AcademicTerm _term;

    public CollegeHeadRoleTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _userRepo = new UserRepository(_context);
        _userDetailsRepo = new UserDetailsRepository(_context);
        _posRepo = new PositionRepository(_context);
        _progRepo = new AcademicProgramRepository(_context);
        _studyLoadRepo = new StudyLoadRepository(_context);
        _classRepo = new ClassRepository(_context);
        _subjectRepo = new SubjectRepository(_context);

        _scopingMock = new Mock<IProgramScopingService>();
        _clearanceMock = new Mock<IGradeClearanceService>();

        _studyLoadService = new StudyLoadService(
            _context,
            _studyLoadRepo,
            _clearanceMock.Object,
            NullLogger<StudyLoadService>.Instance);

        _userDetailsController = new UserDetailsController(
            _userDetailsRepo,
            _scopingMock.Object,
            NullLogger<UserDetailsController>.Instance);

        _studentsController = new StudentsController(_context, _userDetailsRepo);

        _studyLoadsController = new StudyLoadsController(
            _studyLoadService,
            _classRepo,
            _userDetailsRepo,
            _scopingMock.Object);

        _program1 = new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "Information Technology" };
        _program2 = new AcademicProgram { ProgramID = 2, ProgramCode = "BSBA", ProgramName = "Business Administration" };
        _context.AcademicPrograms.AddRange(_program1, _program2);

        _term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 1, IsActive = true };
        _context.AcademicTerms.Add(_term);

        _context.SaveChanges();
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

    private async Task<User> CreateUserWithDetailsAsync(string email, int role, int? programId = null, string? lrn = null)
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

        var details = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = user.UserID,
            Firstname = "First",
            Lastname = "Last",
            ProgramID = programId,
            LRN = lrn
        };
        await _userDetailsRepo.AddAsync(details);
        return user;
    }

    // ── 1. RoleUtils Validation ──────────────────────────────────────────────────

    [Fact]
    public void RoleUtils_CollegeHead_DefinedCorrectly()
    {
        Assert.Equal(6, RoleUtils.CollegeHead);
        Assert.True(RoleUtils.IsValidRole(RoleUtils.CollegeHead));
        Assert.Equal("College Head", RoleUtils.GetRoleName(RoleUtils.CollegeHead));
        Assert.False(RoleUtils.IsValidRole(0));
        Assert.False(RoleUtils.IsValidRole(7));
    }

    // ── 2. Staff Management for College Head ──────────────────────────────────────

    [Fact]
    public async Task StaffService_UpdateStaff_ToCollegeHead_ForcesProgramIdNull()
    {
        var staffService = new StaffService(
            _context,
            _userRepo,
            _userDetailsRepo,
            _posRepo,
            _progRepo,
            new ConfigurationBuilder().Build(),
            NullLogger<StaffService>.Instance);

        var admin = await CreateUserWithDetailsAsync("admin@dbtc-cebu.edu.ph", RoleUtils.Admin);
        var phUser = await CreateUserWithDetailsAsync("ph@dbtc-cebu.edu.ph", RoleUtils.ProgramHead, programId: 1);

        var updateDto = new UpdateStaffDto
        {
            Role = RoleUtils.CollegeHead,
            ProgramID = 2 // Attempting to set ProgramID
        };

        var result = await staffService.UpdateStaffAsync(phUser.UserID, updateDto, admin.UserID);

        Assert.Equal(RoleUtils.CollegeHead, result.Role);
        Assert.Null(result.ProgramID);
        Assert.Null(result.ProgramCode);

        var updatedDetails = await _userDetailsRepo.GetByUserIdAsync(phUser.UserID);
        Assert.Null(updatedDetails?.ProgramID);
    }

    [Fact]
    public async Task StaffService_UpdateStaff_CollegeHeadToProgramHead_RequiresProgramId()
    {
        var staffService = new StaffService(
            _context,
            _userRepo,
            _userDetailsRepo,
            _posRepo,
            _progRepo,
            new ConfigurationBuilder().Build(),
            NullLogger<StaffService>.Instance);

        var admin = await CreateUserWithDetailsAsync("admin@dbtc-cebu.edu.ph", RoleUtils.Admin);
        var chUser = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead, programId: null);

        // Attempt without ProgramID
        var updateDtoNoProg = new UpdateStaffDto
        {
            Role = RoleUtils.ProgramHead
        };

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => staffService.UpdateStaffAsync(chUser.UserID, updateDtoNoProg, admin.UserID));
        Assert.Contains("Academic program is required", ex.Message);

        // Attempt with ProgramID
        var updateDtoWithProg = new UpdateStaffDto
        {
            Role = RoleUtils.ProgramHead,
            ProgramID = 1
        };

        var result = await staffService.UpdateStaffAsync(chUser.UserID, updateDtoWithProg, admin.UserID);
        Assert.Equal(RoleUtils.ProgramHead, result.Role);
        Assert.Equal(1, result.ProgramID);
    }

    // ── 3. College Head Read Access Across Programs ───────────────────────────────

    [Fact]
    public async Task StudentsSearch_CollegeHead_ReturnsStudentsAcrossAllProgramsWithLrn()
    {
        var collegeHead = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var studProg1 = await CreateUserWithDetailsAsync("stud1@dbtc-cebu.edu.ph", RoleUtils.Student, programId: 1, lrn: "111122223333");
        var studProg2 = await CreateUserWithDetailsAsync("stud2@dbtc-cebu.edu.ph", RoleUtils.Student, programId: 2, lrn: "444455556666");

        SetControllerContext(_studentsController, RoleUtils.CollegeHead, collegeHead.UserID);

        var response = await _studentsController.Search(q: null, missingLrn: null, programId: null);
        var okResult = Assert.IsType<OkObjectResult>(response);
        var list = Assert.IsAssignableFrom<List<StudentSearchResultDto>>(okResult.Value);

        Assert.Contains(list, s => s.UserId == studProg1.UserID && s.Lrn == "111122223333" && s.HasLrn);
        Assert.Contains(list, s => s.UserId == studProg2.UserID && s.Lrn == "444455556666" && s.HasLrn);
    }

    [Fact]
    public async Task StudyLoads_GetByStudent_CollegeHead_CanViewAcrossProgramsWithLrn()
    {
        var collegeHead = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var studentProg1 = await CreateUserWithDetailsAsync("s1@dbtc-cebu.edu.ph", RoleUtils.Student, programId: 1, lrn: "123412341234");
        var studentProg2 = await CreateUserWithDetailsAsync("s2@dbtc-cebu.edu.ph", RoleUtils.Student, programId: 2, lrn: "567856785678");

        var sub1 = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT1", SubjectTitle = "IT 1", ProgramID = 1 };
        var sub2 = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "BA1", SubjectTitle = "BA 1", ProgramID = 2 };
        _context.Subjects.AddRange(sub1, sub2);

        var cls1 = new Class { ClassID = Guid.NewGuid(), ClassName = "IT 1", TermID = _term.TermID, SubjectID = sub1.SubjectID };
        var cls2 = new Class { ClassID = Guid.NewGuid(), ClassName = "BA 1", TermID = _term.TermID, SubjectID = sub2.SubjectID };
        _context.Classes.AddRange(cls1, cls2);

        _context.StudyLoads.AddRange(
            new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = studentProg1.UserID, ClassID = cls1.ClassID, LoadStatus = StudyLoadStatus.Enrolled },
            new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = studentProg2.UserID, ClassID = cls2.ClassID, LoadStatus = StudyLoadStatus.Enrolled }
        );
        await _context.SaveChangesAsync();

        SetControllerContext(_studyLoadsController, RoleUtils.CollegeHead, collegeHead.UserID);

        // View Student 1 (Program 1)
        var res1 = await _studyLoadsController.GetByStudent(studentProg1.UserID, _term.TermID);
        var ok1 = Assert.IsType<OkObjectResult>(res1);
        var loads1 = Assert.IsAssignableFrom<List<StudyLoadResponseDto>>(ok1.Value);
        Assert.Single(loads1);
        Assert.True(loads1[0].HasLrn);
        Assert.Equal("123412341234", loads1[0].LRN);

        // View Student 2 (Program 2)
        var res2 = await _studyLoadsController.GetByStudent(studentProg2.UserID, _term.TermID);
        var ok2 = Assert.IsType<OkObjectResult>(res2);
        var loads2 = Assert.IsAssignableFrom<List<StudyLoadResponseDto>>(ok2.Value);
        Assert.Single(loads2);
        Assert.True(loads2[0].HasLrn);
        Assert.Equal("567856785678", loads2[0].LRN);

        // Verify ProgramScopingService was NOT called (unscoped)
        _scopingMock.Verify(s => s.EnsureProgramHeadAccessAsync(It.IsAny<Guid>(), It.IsAny<int?>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task StudyLoads_GetByClass_CollegeHead_CanViewRosterAcrossProgramsWithLrn()
    {
        var collegeHead = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var studentProg1 = await CreateUserWithDetailsAsync("s1@dbtc-cebu.edu.ph", RoleUtils.Student, programId: 1, lrn: "999988887777");

        var sub1 = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "IT1", SubjectTitle = "IT 1", ProgramID = 1 };
        _context.Subjects.Add(sub1);
        var cls1 = new Class { ClassID = Guid.NewGuid(), ClassName = "IT 1", TermID = _term.TermID, SubjectID = sub1.SubjectID };
        _context.Classes.Add(cls1);
        _context.StudyLoads.Add(new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = studentProg1.UserID, ClassID = cls1.ClassID, LoadStatus = StudyLoadStatus.Enrolled });
        await _context.SaveChangesAsync();

        SetControllerContext(_studyLoadsController, RoleUtils.CollegeHead, collegeHead.UserID);

        var res = await _studyLoadsController.GetByClass(cls1.ClassID);
        var ok = Assert.IsType<OkObjectResult>(res);
        var loads = Assert.IsAssignableFrom<List<StudyLoadResponseDto>>(ok.Value);
        Assert.Single(loads);
        Assert.True(loads[0].HasLrn);
        Assert.Equal("999988887777", loads[0].LRN);
    }

    [Fact]
    public async Task UserDetails_Search_CollegeHead_CanSearchTeachersAcrossAllPrograms()
    {
        var collegeHead = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var teacher1 = await CreateUserWithDetailsAsync("t1@dbtc-cebu.edu.ph", RoleUtils.Teacher, programId: 1);
        var teacher2 = await CreateUserWithDetailsAsync("t2@dbtc-cebu.edu.ph", RoleUtils.Teacher, programId: 2);

        SetControllerContext(_userDetailsController, RoleUtils.CollegeHead, collegeHead.UserID);

        // Searching teachers (role=3) succeeds and returns teachers from both programs
        var res = await _userDetailsController.Search(search: null, role: RoleUtils.Teacher);
        var ok = Assert.IsType<OkObjectResult>(res);
        var dtos = Assert.IsAssignableFrom<List<UserSearchResultDto>>(ok.Value);
        Assert.Contains(dtos, d => d.UserID == teacher1.UserID);
        Assert.Contains(dtos, d => d.UserID == teacher2.UserID);
    }

    [Fact]
    public async Task UserDetails_Search_CollegeHead_NonTeacherRoles_Returns403Forbidden()
    {
        var collegeHead = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        SetControllerContext(_userDetailsController, RoleUtils.CollegeHead, collegeHead.UserID);

        // Searching students (role=5) or registrar or without role returns 403
        var resStudents = await _userDetailsController.Search(search: null, role: RoleUtils.Student);
        var statusStudents = Assert.IsType<ObjectResult>(resStudents);
        Assert.Equal(StatusCodes.Status403Forbidden, statusStudents.StatusCode);

        var resNoRole = await _userDetailsController.Search(search: null, role: null);
        var statusNoRole = Assert.IsType<ObjectResult>(resNoRole);
        Assert.Equal(StatusCodes.Status403Forbidden, statusNoRole.StatusCode);
    }

    // ── 4. 403 Forbidden for College Head on Write Attributes ────────────────────

    private ActionExecutingContext CreateFilterContext(Guid userId, IUserRepository userRepo)
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Items["user_id"] = userId;

        var serviceProvider = new Mock<IServiceProvider>();
        serviceProvider.Setup(sp => sp.GetService(typeof(IUserRepository))).Returns(userRepo);
        httpContext.RequestServices = serviceProvider.Object;

        var actionContext = new ActionContext(httpContext, new RouteData(), new ActionDescriptor());
        return new ActionExecutingContext(actionContext, new List<IFilterMetadata>(), new Dictionary<string, object?>(), controller: null!);
    }

    [Fact]
    public async Task RequireProgramHeadOrAdmin_CollegeHead_Returns403Forbidden()
    {
        var collegeHead = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var filter = new RequireProgramHeadOrAdminAttribute();
        var context = CreateFilterContext(collegeHead.UserID, _userRepo);

        bool executed = false;
        await filter.OnActionExecutionAsync(context, () => { executed = true; return Task.FromResult<ActionExecutedContext>(null!); });

        Assert.False(executed);
        var objResult = Assert.IsType<ObjectResult>(context.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, objResult.StatusCode);
    }

    [Fact]
    public async Task RequireRegistrarOrAdmin_CollegeHead_Returns403Forbidden()
    {
        var collegeHead = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var filter = new RequireRegistrarOrAdminAttribute();
        var context = CreateFilterContext(collegeHead.UserID, _userRepo);

        bool executed = false;
        await filter.OnActionExecutionAsync(context, () => { executed = true; return Task.FromResult<ActionExecutedContext>(null!); });

        Assert.False(executed);
        var objResult = Assert.IsType<ObjectResult>(context.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, objResult.StatusCode);
    }

    [Fact]
    public async Task RequireTeacher_CollegeHead_Returns403Forbidden()
    {
        var collegeHead = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var filter = new RequireTeacherAttribute();
        var context = CreateFilterContext(collegeHead.UserID, _userRepo);

        bool executed = false;
        await filter.OnActionExecutionAsync(context, () => { executed = true; return Task.FromResult<ActionExecutedContext>(null!); });

        Assert.False(executed);
        var objResult = Assert.IsType<ObjectResult>(context.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, objResult.StatusCode);
    }

    [Fact]
    public async Task RequireAdmin_CollegeHead_Returns403Forbidden()
    {
        var collegeHead = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var filter = new RequireAdminAttribute();
        var context = CreateFilterContext(collegeHead.UserID, _userRepo);

        bool executed = false;
        await filter.OnActionExecutionAsync(context, () => { executed = true; return Task.FromResult<ActionExecutedContext>(null!); });

        Assert.False(executed);
        var objResult = Assert.IsType<ObjectResult>(context.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, objResult.StatusCode);
    }

    [Fact]
    public async Task RequireRegistrarCollegeHeadOrAdmin_AllowsRegistrarCollegeHeadAdmin_RejectsOthers()
    {
        var filter = new RequireRegistrarCollegeHeadOrAdminAttribute();

        var ch = await CreateUserWithDetailsAsync("ch_allowed@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var reg = await CreateUserWithDetailsAsync("reg_allowed@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var adm = await CreateUserWithDetailsAsync("adm_allowed@dbtc-cebu.edu.ph", RoleUtils.Admin);
        var ph = await CreateUserWithDetailsAsync("ph_blocked@dbtc-cebu.edu.ph", RoleUtils.ProgramHead);
        var tch = await CreateUserWithDetailsAsync("tch_blocked@dbtc-cebu.edu.ph", RoleUtils.Teacher);

        // Allowed:
        foreach (var user in new[] { ch, reg, adm })
        {
            var ctx = CreateFilterContext(user.UserID, _userRepo);
            bool executed = false;
            await filter.OnActionExecutionAsync(ctx, () => { executed = true; return Task.FromResult<ActionExecutedContext>(null!); });
            Assert.True(executed);
            Assert.Null(ctx.Result);
        }

        // Blocked:
        foreach (var user in new[] { ph, tch })
        {
            var ctx = CreateFilterContext(user.UserID, _userRepo);
            bool executed = false;
            await filter.OnActionExecutionAsync(ctx, () => { executed = true; return Task.FromResult<ActionExecutedContext>(null!); });
            Assert.False(executed);
            var objResult = Assert.IsType<ObjectResult>(ctx.Result);
            Assert.Equal(StatusCodes.Status403Forbidden, objResult.StatusCode);
        }
    }

    [Fact]
    public async Task RequireCollegeHeadOrAdmin_AllowsCollegeHeadAndAdmin_RejectsRegistrar()
    {
        var filter = new RequireCollegeHeadOrAdminAttribute();

        var ch = await CreateUserWithDetailsAsync("ch_ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var adm = await CreateUserWithDetailsAsync("adm_adm@dbtc-cebu.edu.ph", RoleUtils.Admin);
        var reg = await CreateUserWithDetailsAsync("reg_rej@dbtc-cebu.edu.ph", RoleUtils.Registrar);

        // Allowed:
        foreach (var user in new[] { ch, adm })
        {
            var ctx = CreateFilterContext(user.UserID, _userRepo);
            bool executed = false;
            await filter.OnActionExecutionAsync(ctx, () => { executed = true; return Task.FromResult<ActionExecutedContext>(null!); });
            Assert.True(executed);
            Assert.Null(ctx.Result);
        }

        // Registrar blocked:
        var regCtx = CreateFilterContext(reg.UserID, _userRepo);
        bool regExecuted = false;
        await filter.OnActionExecutionAsync(regCtx, () => { regExecuted = true; return Task.FromResult<ActionExecutedContext>(null!); });
        Assert.False(regExecuted);
        var objResult = Assert.IsType<ObjectResult>(regCtx.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, objResult.StatusCode);
    }

    [Fact]
    public async Task StaffService_UpdateStaff_RegistrarToCollegeHead_ForcesProgramIdNull()
    {
        var staffService = new StaffService(
            _context,
            _userRepo,
            _userDetailsRepo,
            _posRepo,
            _progRepo,
            new ConfigurationBuilder().Build(),
            NullLogger<StaffService>.Instance);

        var admin = await CreateUserWithDetailsAsync("admin@dbtc-cebu.edu.ph", RoleUtils.Admin);
        var regUser = await CreateUserWithDetailsAsync("reg@dbtc-cebu.edu.ph", RoleUtils.Registrar);

        var updateDto = new UpdateStaffDto
        {
            Role = RoleUtils.CollegeHead,
            ProgramID = 1 // Even if programId is supplied, it must be cleared
        };

        var result = await staffService.UpdateStaffAsync(regUser.UserID, updateDto, admin.UserID);

        Assert.Equal(RoleUtils.CollegeHead, result.Role);
        Assert.Null(result.ProgramID);
        Assert.Null(result.ProgramCode);

        var updatedDetails = await _userDetailsRepo.GetByUserIdAsync(regUser.UserID);
        Assert.Null(updatedDetails?.ProgramID);
    }

    [Fact]
    public async Task GradeCorrection_Request_CollegeHead_Returns403Forbidden()
    {
        var teacher = await CreateUserWithDetailsAsync("teacher@dbtc-cebu.edu.ph", RoleUtils.Teacher);
        var collegeHead = await CreateUserWithDetailsAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var student = await CreateUserWithDetailsAsync("student@dbtc-cebu.edu.ph", RoleUtils.Student);

        var sub = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "CS101", SubjectTitle = "CS 101", ProgramID = 1 };
        _context.Subjects.Add(sub);

        var cls = new Class { ClassID = Guid.NewGuid(), ClassName = "CS101 - A", TermID = _term.TermID, SubjectID = sub.SubjectID, UserID = teacher.UserID };
        _context.Classes.Add(cls);

        var sl = new StudyLoad { StudyLoadID = Guid.NewGuid(), ClassID = cls.ClassID, UserID = student.UserID, LoadStatus = StudyLoadStatus.Enrolled };
        _context.StudyLoads.Add(sl);

        var grade = new Domain.Grading.Grade
        {
            GradeID = Guid.NewGuid(),
            StudyLoadID = sl.StudyLoadID,
            MidtermGrade = 2.0m,
            SubmittedByUserID = teacher.UserID,
            DateSubmitted = DateTime.UtcNow
        };
        _context.Grades.Add(grade);
        await _context.SaveChangesAsync();

        var gradeRepo = new GradeRepository(_context);
        var correctionRepo = new GradeCorrectionRepository(_context);
        var correctionService = new GradeCorrectionService(_context, correctionRepo, gradeRepo);
        var controller = new GradeCorrectionsController(correctionService);

        SetControllerContext(controller, RoleUtils.CollegeHead, collegeHead.UserID);

        var reqDto = new DTOs.Grading.CreateGradeCorrectionDto
        {
            GradeId = grade.GradeID,
            CorrectionPeriod = 1,
            OldGrade = 2.0m,
            NewGrade = 1.5m,
            Reason = "Re-evaluation"
        };

        var result = await controller.RequestCorrection(reqDto);
        var objResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, objResult.StatusCode);
    }

    [Fact]
    public void WriteEndpoints_DecoratedWithForbiddenAttributesForCollegeHead()
    {
        // 1. ClassesController write actions -> RequireProgramHeadOrAdmin
        AssertActionHasFilter<ClassesController>("Create", typeof(RequireProgramHeadOrAdminAttribute));
        AssertActionHasFilter<ClassesController>("Update", typeof(RequireProgramHeadOrAdminAttribute));
        AssertActionHasFilter<ClassesController>("Delete", typeof(RequireProgramHeadOrAdminAttribute));
        AssertActionHasFilter<ClassesController>("AssignTeacher", typeof(RequireProgramHeadOrAdminAttribute));
        AssertActionHasFilter<ClassesController>("CreateSchedule", typeof(RequireProgramHeadOrAdminAttribute));

        // 2. ClassSchedulesController write actions -> RequireProgramHeadOrAdmin
        AssertActionHasFilter<ClassSchedulesController>("Update", typeof(RequireProgramHeadOrAdminAttribute));
        AssertActionHasFilter<ClassSchedulesController>("Delete", typeof(RequireProgramHeadOrAdminAttribute));

        // 3. StudyLoadsController write actions -> RequireRegistrarOrAdmin
        AssertActionHasFilter<StudyLoadsController>("EnrollSingle", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<StudyLoadsController>("EnrollBatch", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<StudyLoadsController>("UpdateStatus", typeof(RequireRegistrarOrAdminAttribute));

        // 4. GradesController write actions -> RequireTeacher
        AssertActionHasFilter<GradesController>("SubmitGrade", typeof(RequireTeacherAttribute));
        AssertActionHasFilter<GradesController>("SubmitGradeBatch", typeof(RequireTeacherAttribute));

        // 5. GradeCorrectionsController write actions -> RequireRegistrarOrAdmin
        AssertActionHasFilter<GradeCorrectionsController>("ApproveCorrection", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<GradeCorrectionsController>("RejectCorrection", typeof(RequireRegistrarOrAdminAttribute));

        // 6. GradeClearancesController write actions -> RequireRegistrarOrAdmin
        AssertActionHasFilter<GradeClearancesController>("SetClearance", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<GradeClearancesController>("CreateClearance", typeof(RequireRegistrarOrAdminAttribute));

        // 7. SubjectsController write actions -> RequireRegistrarOrAdmin
        AssertActionHasFilter<SubjectsController>("Create", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<SubjectsController>("Update", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<SubjectsController>("Delete", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<SubjectsController>("AddPrerequisite", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<SubjectsController>("RemovePrerequisite", typeof(RequireRegistrarOrAdminAttribute));

        // 8. AcademicTermsController write actions -> RequireRegistrarOrAdmin
        AssertActionHasFilter<AcademicTermsController>("Create", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<AcademicTermsController>("Update", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<AcademicTermsController>("Activate", typeof(RequireRegistrarOrAdminAttribute));
        AssertActionHasFilter<AcademicTermsController>("Delete", typeof(RequireRegistrarOrAdminAttribute));

        // 9. AdminStaffController -> RequireAdmin (controller-level)
        AssertControllerHasFilter<AdminStaffController>(typeof(RequireAdminAttribute));

        // 10. UserDetailsController.UpdateLrn -> RequireRegistrarOrAdmin
        AssertActionHasFilter<UserDetailsController>("UpdateLrn", typeof(RequireRegistrarOrAdminAttribute));

        // 11. EnrollmentApplicationsController -> RequireRegistrarOrAdmin (controller-level)
        AssertControllerHasFilter<EnrollmentApplicationsController>(typeof(RequireRegistrarOrAdminAttribute));
    }

    private static void AssertActionHasFilter<TController>(string methodName, Type filterType)
    {
        var method = typeof(TController).GetMethod(methodName);
        Assert.NotNull(method);
        var hasAttr = method.GetCustomAttributes(filterType, true).Length > 0;
        Assert.True(hasAttr, $"{typeof(TController).Name}.{methodName} must be decorated with {filterType.Name}");
    }

    private static void AssertControllerHasFilter<TController>(Type filterType)
    {
        var hasAttr = typeof(TController).GetCustomAttributes(filterType, true).Length > 0;
        Assert.True(hasAttr, $"{typeof(TController).Name} must be decorated with {filterType.Name}");
    }
}
