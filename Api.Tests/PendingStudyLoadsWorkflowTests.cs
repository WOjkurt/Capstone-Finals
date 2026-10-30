using Api.Auth;
using Api.Constants;
using Api.Controllers;
using Api.Data;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.Grading;
using Api.DTOs.StudyLoad;
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
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Xunit;

namespace Api.Tests;

public class PendingStudyLoadsWorkflowTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly IUserRepository _userRepo;
    private readonly IUserDetailsRepository _userDetailsRepo;
    private readonly IStudyLoadRepository _studyLoadRepo;
    private readonly IClassRepository _classRepo;
    private readonly ISubjectRepository _subjectRepo;
    private readonly Mock<IGradeClearanceService> _clearanceMock;
    private readonly Mock<IProgramScopingService> _scopingMock;
    private readonly IStudyLoadService _studyLoadService;
    private readonly StudyLoadsController _studyLoadsController;
    private readonly AcademicProgram _program;
    private readonly AcademicTerm _term;

    public PendingStudyLoadsWorkflowTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _userRepo = new UserRepository(_context);
        _userDetailsRepo = new UserDetailsRepository(_context);
        _studyLoadRepo = new StudyLoadRepository(_context);
        _classRepo = new ClassRepository(_context);
        _subjectRepo = new SubjectRepository(_context);

        _clearanceMock = new Mock<IGradeClearanceService>();
        _clearanceMock.Setup(c => c.IsClearedAsync(It.IsAny<Guid>(), It.IsAny<Guid>())).ReturnsAsync(true);

        _scopingMock = new Mock<IProgramScopingService>();

        _studyLoadService = new StudyLoadService(
            _context,
            _studyLoadRepo,
            _clearanceMock.Object,
            NullLogger<StudyLoadService>.Instance);

        _studyLoadsController = new StudyLoadsController(
            _studyLoadService,
            _classRepo,
            _userDetailsRepo,
            _scopingMock.Object);

        _program = new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "Information Technology" };
        _context.AcademicPrograms.Add(_program);

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

    private ActionExecutingContext CreateFilterContext(Guid userId, IUserRepository userRepo)
    {
        var services = new Mock<IServiceProvider>();
        services.Setup(s => s.GetService(typeof(IUserRepository))).Returns(userRepo);

        var httpContext = new DefaultHttpContext { RequestServices = services.Object };
        httpContext.Items["user_id"] = userId;

        var actionContext = new ActionContext(httpContext, new RouteData(), new ActionDescriptor());
        return new ActionExecutingContext(actionContext, new List<IFilterMetadata>(), new Dictionary<string, object?>(), null!);
    }

    private async Task<(User User, UserDetails Details)> CreateStudentAsync(string email = "student@dbtc-cebu.edu.ph", int yearLevel = 1)
    {
        var user = new User
        {
            UserID = Guid.NewGuid(),
            Email = email,
            FirebaseUID = $"fb-{Guid.NewGuid():N}",
            Role = RoleUtils.Student,
            IsActive = true
        };
        await _userRepo.AddAsync(user);

        var details = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = user.UserID,
            Firstname = "Juan",
            Lastname = "Dela Cruz",
            ProgramID = _program.ProgramID,
            YearLevel = yearLevel,
            LRN = "123456789012"
        };
        await _userDetailsRepo.AddAsync(details);
        return (user, details);
    }

    private async Task<User> CreateStaffUserAsync(string email, int role)
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
            Firstname = "Staff",
            Lastname = RoleUtils.GetRoleName(role)
        };
        await _userDetailsRepo.AddAsync(details);
        return user;
    }

    private async Task<(Subject Subject, Class Class)> CreateSubjectAndClassAsync(string code, string title, decimal lecUnits = 3m, decimal labUnits = 0m)
    {
        var subject = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = code,
            SubjectTitle = title,
            ProgramID = _program.ProgramID,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = lecUnits,
            LabUnits = labUnits
        };
        _context.Subjects.Add(subject);

        var c = new Class
        {
            ClassID = Guid.NewGuid(),
            SubjectID = subject.SubjectID,
            TermID = _term.TermID,
            ClassName = $"{code}-SEC1",
            CreatedAt = DateTime.UtcNow
        };
        _context.Classes.Add(c);
        await _context.SaveChangesAsync();

        return (subject, c);
    }

    [Fact]
    public async Task CollegeHead_CanCallProposedBlock_EnrollBatch_EnrollSingle_AndLoadsAreAlwaysPending()
    {
        var ch = await CreateStaffUserAsync("ch@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var (student, _) = await CreateStudentAsync();
        var (_, c1) = await CreateSubjectAndClassAsync("IT101", "Intro to IT");
        var (_, c2) = await CreateSubjectAndClassAsync("IT102", "Programming 1");

        SetControllerContext(_studyLoadsController, RoleUtils.CollegeHead, ch.UserID);

        // 1. Proposed block works
        var proposedResult = await _studyLoadsController.GetProposedBlock(student.UserID, _term.TermID);
        var okProposed = Assert.IsType<OkObjectResult>(proposedResult);
        var block = Assert.IsType<List<ProposedBlockItemDto>>(okProposed.Value);
        Assert.NotEmpty(block);

        // 2. Enroll batch creates PENDING even when AsPending is false
        var batchResult = await _studyLoadsController.EnrollBatch(new EnrollBatchRequestDto
        {
            UserId = student.UserID,
            TermId = _term.TermID,
            ClassIds = new List<Guid> { c1.ClassID },
            AsPending = false // College Head cannot create Enrolled directly!
        });
        var okBatch = Assert.IsType<OkObjectResult>(batchResult);
        var batchRes = Assert.IsType<List<EnrollBatchResponseDto>>(okBatch.Value);
        Assert.True(batchRes[0].Enrolled);

        var sl1 = await _context.StudyLoads.FindAsync(batchRes[0].StudyLoadId);
        Assert.NotNull(sl1);
        Assert.Equal(StudyLoadStatus.Pending, sl1.LoadStatus);

        // 3. Clearance is NOT created for pending load
        _clearanceMock.Verify(c => c.EnsureClearanceAsync(It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);

        // 4. Enroll single creates PENDING even when AsPending is false
        var singleResult = await _studyLoadsController.EnrollSingle(new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = c2.ClassID,
            AsPending = false
        });
        var okSingle = Assert.IsType<OkObjectResult>(singleResult);
        var singleRes = Assert.IsType<EnrollSingleResponseDto>(okSingle.Value);
        Assert.True(singleRes.Success);

        var sl2 = await _context.StudyLoads.FindAsync(singleRes.StudyLoadId);
        Assert.NotNull(sl2);
        Assert.Equal(StudyLoadStatus.Pending, sl2.LoadStatus);

        _clearanceMock.Verify(c => c.EnsureClearanceAsync(It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task CollegeHead_BlockedFromFinalize_AndStatusPatch()
    {
        var filter = new RequireRegistrarOrAdminAttribute();
        var ch = await CreateStaffUserAsync("ch_block@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);

        var ctx = CreateFilterContext(ch.UserID, _userRepo);
        bool executed = false;
        await filter.OnActionExecutionAsync(ctx, () => { executed = true; return Task.FromResult<ActionExecutedContext>(null!); });

        Assert.False(executed);
        var objResult = Assert.IsType<ObjectResult>(ctx.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, objResult.StatusCode);
    }

    [Fact]
    public async Task Registrar_Enroll_AsPendingTrue_CreatesPendingWithoutClearance_DefaultCreatesEnrolledWithClearance()
    {
        var reg = await CreateStaffUserAsync("reg@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var (student, _) = await CreateStudentAsync("reg_std@dbtc-cebu.edu.ph");
        var (_, c1) = await CreateSubjectAndClassAsync("ENG1", "English 1");
        var (_, c2) = await CreateSubjectAndClassAsync("MATH1", "Math 1");

        SetControllerContext(_studyLoadsController, RoleUtils.Registrar, reg.UserID);

        // 1. AsPending true -> Pending & no clearance
        var pendingRes = await _studyLoadsController.EnrollSingle(new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = c1.ClassID,
            AsPending = true
        });
        var okPending = Assert.IsType<OkObjectResult>(pendingRes);
        var slPendingDto = Assert.IsType<EnrollSingleResponseDto>(okPending.Value);
        var slPending = await _context.StudyLoads.FindAsync(slPendingDto.StudyLoadId);
        Assert.Equal(StudyLoadStatus.Pending, slPending!.LoadStatus);
        _clearanceMock.Verify(c => c.EnsureClearanceAsync(student.UserID, _term.TermID), Times.Never);

        // 2. Default AsPending false -> Enrolled & ensures clearance
        var enrolledRes = await _studyLoadsController.EnrollSingle(new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = c2.ClassID,
            AsPending = false
        });
        var okEnrolled = Assert.IsType<OkObjectResult>(enrolledRes);
        var slEnrolledDto = Assert.IsType<EnrollSingleResponseDto>(okEnrolled.Value);
        var slEnrolled = await _context.StudyLoads.FindAsync(slEnrolledDto.StudyLoadId);
        Assert.Equal(StudyLoadStatus.Enrolled, slEnrolled!.LoadStatus);
        _clearanceMock.Verify(c => c.EnsureClearanceAsync(student.UserID, _term.TermID), Times.Once);
    }

    [Fact]
    public async Task Finalize_AllPending_Success_EnsuresClearanceAndPreservesForcedAudit()
    {
        var reg = await CreateStaffUserAsync("reg2@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var (student, _) = await CreateStudentAsync("std_fin@dbtc-cebu.edu.ph");
        var (_, c1) = await CreateSubjectAndClassAsync("PHY1", "Physics 1");
        var (_, c2) = await CreateSubjectAndClassAsync("CHEM1", "Chemistry 1");

        // Seed 2 pending study loads, one forced
        var sl1 = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c1.ClassID,
            LoadStatus = StudyLoadStatus.Pending,
            CreatedAt = DateTime.UtcNow,
            IsForced = true,
            ForcedByUserID = reg.UserID,
            ForcedReason = "College Head approved prerequisite override"
        };
        var sl2 = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c2.ClassID,
            LoadStatus = StudyLoadStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.AddRange(sl1, sl2);
        await _context.SaveChangesAsync();

        SetControllerContext(_studyLoadsController, RoleUtils.Registrar, reg.UserID);

        // Finalize all (StudyLoadIds null)
        var result = await _studyLoadsController.FinalizeBatch(new FinalizeStudyLoadsRequestDto
        {
            UserId = student.UserID,
            TermId = _term.TermID,
            StudyLoadIds = null
        });

        var okResult = Assert.IsType<OkObjectResult>(result);
        var resDto = Assert.IsType<FinalizeStudyLoadsResponseDto>(okResult.Value);
        Assert.True(resDto.Success);
        Assert.Equal(2, resDto.FinalizedLoads.Count);

        // Check db state
        var updated1 = await _context.StudyLoads.FindAsync(sl1.StudyLoadID);
        var updated2 = await _context.StudyLoads.FindAsync(sl2.StudyLoadID);
        Assert.Equal(StudyLoadStatus.Enrolled, updated1!.LoadStatus);
        Assert.Equal(StudyLoadStatus.Enrolled, updated2!.LoadStatus);

        // Check forced fields survived
        Assert.True(updated1.IsForced);
        Assert.Equal(reg.UserID, updated1.ForcedByUserID);
        Assert.Equal("College Head approved prerequisite override", updated1.ForcedReason);

        // Clearance called once
        _clearanceMock.Verify(c => c.EnsureClearanceAsync(student.UserID, _term.TermID), Times.Once);
    }

    [Fact]
    public async Task Finalize_ChosenSubset_OnlyFinalizesSelectedLoads()
    {
        var reg = await CreateStaffUserAsync("reg3@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var (student, _) = await CreateStudentAsync("std_subset@dbtc-cebu.edu.ph");
        var (_, c1) = await CreateSubjectAndClassAsync("SUB1", "Subject 1");
        var (_, c2) = await CreateSubjectAndClassAsync("SUB2", "Subject 2");

        var sl1 = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c1.ClassID,
            LoadStatus = StudyLoadStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };
        var sl2 = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c2.ClassID,
            LoadStatus = StudyLoadStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.AddRange(sl1, sl2);
        await _context.SaveChangesAsync();

        SetControllerContext(_studyLoadsController, RoleUtils.Registrar, reg.UserID);

        // Finalize only sl1
        var result = await _studyLoadsController.FinalizeBatch(new FinalizeStudyLoadsRequestDto
        {
            UserId = student.UserID,
            TermId = _term.TermID,
            StudyLoadIds = new List<Guid> { sl1.StudyLoadID }
        });

        var okResult = Assert.IsType<OkObjectResult>(result);
        var resDto = Assert.IsType<FinalizeStudyLoadsResponseDto>(okResult.Value);
        Assert.True(resDto.Success);
        Assert.Single(resDto.FinalizedLoads);

        Assert.Equal(StudyLoadStatus.Enrolled, (await _context.StudyLoads.FindAsync(sl1.StudyLoadID))!.LoadStatus);
        Assert.Equal(StudyLoadStatus.Pending, (await _context.StudyLoads.FindAsync(sl2.StudyLoadID))!.LoadStatus);
    }

    [Fact]
    public async Task Finalize_NonPendingId_Returns400()
    {
        var reg = await CreateStaffUserAsync("reg4@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var (student, _) = await CreateStudentAsync("std_nonpending@dbtc-cebu.edu.ph");
        var (_, c1) = await CreateSubjectAndClassAsync("SUB3", "Subject 3");

        var sl1 = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c1.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled, // Already enrolled!
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(sl1);
        await _context.SaveChangesAsync();

        SetControllerContext(_studyLoadsController, RoleUtils.Registrar, reg.UserID);

        var result = await _studyLoadsController.FinalizeBatch(new FinalizeStudyLoadsRequestDto
        {
            UserId = student.UserID,
            TermId = _term.TermID,
            StudyLoadIds = new List<Guid> { sl1.StudyLoadID }
        });

        var badResult = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Contains("Only Pending", badResult.Value!.ToString()!);
    }

    [Fact]
    public async Task Finalize_BlockingFinding_RollsBackAll()
    {
        var reg = await CreateStaffUserAsync("reg5@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var (student, _) = await CreateStudentAsync("std_block@dbtc-cebu.edu.ph");
        var (s1, c1) = await CreateSubjectAndClassAsync("PREREQ1", "Prereq Subject");
        var (s2, c2) = await CreateSubjectAndClassAsync("TARGET1", "Target Subject");

        // Add prerequisite requirement: s2 requires s1
        _context.SubjectPrerequisites.Add(new SubjectPrerequisite
        {
            PrerequisiteID = Guid.NewGuid(),
            SubjectID = s2.SubjectID,
            PrerequisiteSubjectID = s1.SubjectID,
            RequisiteType = RequisiteTypeConstants.Prerequisite
        });

        var sl1 = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c2.ClassID,
            LoadStatus = StudyLoadStatus.Pending,
            IsForced = false, // Not forced! Prereq s1 was never taken!
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(sl1);
        await _context.SaveChangesAsync();

        SetControllerContext(_studyLoadsController, RoleUtils.Registrar, reg.UserID);

        var result = await _studyLoadsController.FinalizeBatch(new FinalizeStudyLoadsRequestDto
        {
            UserId = student.UserID,
            TermId = _term.TermID,
            StudyLoadIds = new List<Guid> { sl1.StudyLoadID }
        });

        var badResult = Assert.IsType<BadRequestObjectResult>(result);
        var resDto = Assert.IsType<FinalizeStudyLoadsResponseDto>(badResult.Value);
        Assert.False(resDto.Success);
        Assert.NotEmpty(resDto.Findings);
        Assert.Equal(EnrollmentRuleCodes.PrerequisiteNotTaken, resDto.Findings[0].Code);

        // Remains Pending!
        var inDb = await _context.StudyLoads.FindAsync(sl1.StudyLoadID);
        Assert.Equal(StudyLoadStatus.Pending, inDb!.LoadStatus);
    }

    [Fact]
    public async Task PatchStatus_PendingToEnrolled_EnsuresClearance_PendingToDropped_Works()
    {
        var reg = await CreateStaffUserAsync("reg6@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var (student, _) = await CreateStudentAsync("std_patch@dbtc-cebu.edu.ph");
        var (_, c1) = await CreateSubjectAndClassAsync("SUB_P1", "Subject Patch 1");
        var (_, c2) = await CreateSubjectAndClassAsync("SUB_P2", "Subject Patch 2");

        var sl1 = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c1.ClassID,
            LoadStatus = StudyLoadStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };
        var sl2 = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c2.ClassID,
            LoadStatus = StudyLoadStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.AddRange(sl1, sl2);
        await _context.SaveChangesAsync();

        SetControllerContext(_studyLoadsController, RoleUtils.Registrar, reg.UserID);

        // 1. Pending -> Enrolled: creates clearance
        var patch1 = await _studyLoadsController.UpdateStatus(sl1.StudyLoadID, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Enrolled });
        Assert.IsType<OkObjectResult>(patch1);
        _clearanceMock.Verify(c => c.EnsureClearanceAsync(student.UserID, _term.TermID), Times.Once);

        // 2. Pending -> Dropped: works without error (rejection)
        var patch2 = await _studyLoadsController.UpdateStatus(sl2.StudyLoadID, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Dropped });
        Assert.IsType<OkObjectResult>(patch2);
        var inDb2 = await _context.StudyLoads.FindAsync(sl2.StudyLoadID);
        Assert.Equal(StudyLoadStatus.Dropped, inDb2!.LoadStatus);
    }

    [Fact]
    public async Task PendingSummary_ReturnsOnlyStudentsWithPendingLoads_RoleMatrixChecked()
    {
        var reg = await CreateStaffUserAsync("reg7@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var (studentWithPending, _) = await CreateStudentAsync("std_has_pending@dbtc-cebu.edu.ph");
        var (studentEnrolledOnly, _) = await CreateStudentAsync("std_enrolled_only@dbtc-cebu.edu.ph");
        var (_, c1) = await CreateSubjectAndClassAsync("SUM1", "Summary Subject 1", lecUnits: 3m, labUnits: 1m);

        // Student 1 has Pending
        _context.StudyLoads.Add(new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = studentWithPending.UserID,
            ClassID = c1.ClassID,
            LoadStatus = StudyLoadStatus.Pending,
            CreatedAt = DateTime.UtcNow
        });

        // Student 2 has Enrolled only
        _context.StudyLoads.Add(new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = studentEnrolledOnly.UserID,
            ClassID = c1.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        SetControllerContext(_studyLoadsController, RoleUtils.Registrar, reg.UserID);

        var result = await _studyLoadsController.GetPendingSummary(_term.TermID);
        var okResult = Assert.IsType<OkObjectResult>(result);
        var summary = Assert.IsType<List<PendingStudyLoadSummaryDto>>(okResult.Value);

        Assert.Single(summary);
        Assert.Equal(studentWithPending.UserID, summary[0].UserId);
        Assert.Equal(1, summary[0].PendingCount);
        Assert.Equal(4m, summary[0].PendingUnits); // 3 + 1

        // Attribute check on pending-summary: Registrar, CollegeHead, Admin allowed; Teacher and Student rejected
        var filter = new RequireRegistrarCollegeHeadOrAdminAttribute();
        var tch = await CreateStaffUserAsync("tch_rej@dbtc-cebu.edu.ph", RoleUtils.Teacher);
        var std = studentWithPending;

        var tchCtx = CreateFilterContext(tch.UserID, _userRepo);
        bool tchExecuted = false;
        await filter.OnActionExecutionAsync(tchCtx, () => { tchExecuted = true; return Task.FromResult<ActionExecutedContext>(null!); });
        Assert.False(tchExecuted);
        Assert.Equal(StatusCodes.Status403Forbidden, Assert.IsType<ObjectResult>(tchCtx.Result).StatusCode);

        var stdCtx = CreateFilterContext(std.UserID, _userRepo);
        bool stdExecuted = false;
        await filter.OnActionExecutionAsync(stdCtx, () => { stdExecuted = true; return Task.FromResult<ActionExecutedContext>(null!); });
        Assert.False(stdExecuted);
        Assert.Equal(StatusCodes.Status403Forbidden, Assert.IsType<ObjectResult>(stdCtx.Result).StatusCode);
    }

    [Fact]
    public async Task TeacherRoster_ExcludesPending_EnrolledCountExcludesPending_GradeSubmitRequiresEnrolled()
    {
        var tch = await CreateStaffUserAsync("teacher_guard@dbtc-cebu.edu.ph", RoleUtils.Teacher);
        var (student, _) = await CreateStudentAsync("std_guard@dbtc-cebu.edu.ph");
        var (_, c1) = await CreateSubjectAndClassAsync("GUARD1", "Guard Subject");

        c1.UserID = tch.UserID;
        await _context.SaveChangesAsync();

        var pendingLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c1.ClassID,
            LoadStatus = StudyLoadStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(pendingLoad);
        await _context.SaveChangesAsync();

        // 1. Teacher roster excludes Pending
        SetControllerContext(_studyLoadsController, RoleUtils.Teacher, tch.UserID);
        var rosterResult = await _studyLoadsController.GetByClass(c1.ClassID);
        var okRoster = Assert.IsType<OkObjectResult>(rosterResult);
        var roster = Assert.IsType<List<StudyLoadResponseDto>>(okRoster.Value);
        Assert.Empty(roster);

        // 2. ClassDto EnrolledCount excludes Pending
        var scheduleRepo = new ClassScheduleRepository(_context);
        var classService = new ClassService(_context, _classRepo, scheduleRepo);
        var classDto = await classService.GetByIdAsync(c1.ClassID);
        Assert.Equal(0, classDto!.EnrolledCount);

        // 3. Grade submit on Pending load fails
        var gradeRepo = new GradeRepository(_context);
        var scopingMock = new Mock<IProgramScopingService>();
        var gradeService = new GradeService(_context, gradeRepo, _clearanceMock.Object, scopingMock.Object);
        await Assert.ThrowsAsync<InvalidOperationException>(() => gradeService.SubmitGradeAsync(new SubmitGradeDto
        {
            StudyLoadId = pendingLoad.StudyLoadID,
            MidtermGrade = 85.0m
        }, tch.UserID));
    }

    [Fact]
    public async Task RejectedLoad_IsNotAcademicEvidence_IgnoredInHasSatisfiedSubject()
    {
        // A Rejected study load must NOT count as any form of academic evidence.
        var (student, _) = await CreateStudentAsync("std_rejected_evi@dbtc-cebu.edu.ph");
        var (subject, c1) = await CreateSubjectAndClassAsync("REJ1", "Rejected Subject");

        // Seed a Rejected study load for that subject
        var rejLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c1.ClassID,
            LoadStatus = StudyLoadStatus.Rejected,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(rejLoad);
        await _context.SaveChangesAsync();

        // A second class for the same subject in the same term
        var c2 = new Class
        {
            ClassID = Guid.NewGuid(),
            SubjectID = subject.SubjectID,
            TermID = _term.TermID,
            ClassName = "REJ1-SEC2",
            CreatedAt = DateTime.UtcNow
        };
        _context.Classes.Add(c2);
        await _context.SaveChangesAsync();

        // ValidateEnrollmentRulesAsync must NOT produce SAME_SUBJECT_THIS_TERM or ALREADY_PASSED
        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, c2.ClassID, _term.TermID);
        Assert.DoesNotContain(findings, f => f.Code == EnrollmentRuleCodes.SameSubjectThisTerm);
        Assert.DoesNotContain(findings, f => f.Code == EnrollmentRuleCodes.AlreadyPassed);
    }

    [Fact]
    public async Task RejectedLoad_DoesNotBlock_SameSubjectThisTerm_CanBeProposedAgain()
    {
        var reg = await CreateStaffUserAsync("reg_rej@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var (student, _) = await CreateStudentAsync("std_rej_propose@dbtc-cebu.edu.ph");
        var (_, c1) = await CreateSubjectAndClassAsync("REJPROP1", "Reject Propose Subject");

        // Seed a Rejected study load for the class
        var rejLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c1.ClassID,
            LoadStatus = StudyLoadStatus.Rejected,
            CreatedAt = DateTime.UtcNow.AddMinutes(-5)
        };
        _context.StudyLoads.Add(rejLoad);
        await _context.SaveChangesAsync();

        // Registrar proposes the SAME class again (as Pending) - should succeed
        SetControllerContext(_studyLoadsController, RoleUtils.Registrar, reg.UserID);
        var result = await _studyLoadsController.EnrollSingle(new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = c1.ClassID,
            AsPending = true
        });

        var ok = Assert.IsType<OkObjectResult>(result);
        var dto = Assert.IsType<EnrollSingleResponseDto>(ok.Value);
        Assert.True(dto.Success);

        // New load must be Pending (not Enrolled), and is a NEW row
        var newLoad = await _context.StudyLoads.FindAsync(dto.StudyLoadId);
        Assert.NotNull(newLoad);
        Assert.Equal(StudyLoadStatus.Pending, newLoad.LoadStatus);
        Assert.NotEqual(rejLoad.StudyLoadID, newLoad.StudyLoadID);
    }

    [Fact]
    public async Task PatchStatus_OnlyPendingCanMoveToRejected_NonPendingToRejectedFails()
    {
        var reg = await CreateStaffUserAsync("reg_rej_patch@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var (student, _) = await CreateStudentAsync("std_rej_patch@dbtc-cebu.edu.ph");
        var (_, c1) = await CreateSubjectAndClassAsync("REJPATCH1", "Reject Patch 1");
        var (_, c2) = await CreateSubjectAndClassAsync("REJPATCH2", "Reject Patch 2");

        var pendingLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c1.ClassID,
            LoadStatus = StudyLoadStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };
        var enrolledLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = c2.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.AddRange(pendingLoad, enrolledLoad);
        await _context.SaveChangesAsync();

        SetControllerContext(_studyLoadsController, RoleUtils.Registrar, reg.UserID);

        // 1. Pending -> Rejected: succeeds
        var okResult = await _studyLoadsController.UpdateStatus(
            pendingLoad.StudyLoadID,
            new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Rejected });
        Assert.IsType<OkObjectResult>(okResult);
        var inDb = await _context.StudyLoads.FindAsync(pendingLoad.StudyLoadID);
        Assert.Equal(StudyLoadStatus.Rejected, inDb!.LoadStatus);

        // 2. Enrolled -> Rejected: must fail with BadRequest
        var badResult = await _studyLoadsController.UpdateStatus(
            enrolledLoad.StudyLoadID,
            new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Rejected });
        var bad = Assert.IsType<BadRequestObjectResult>(badResult);
        Assert.Contains("Only Pending", bad.Value!.ToString()!);

        // 3. Setting status to Pending (4) via this endpoint is also forbidden
        var badPending = await _studyLoadsController.UpdateStatus(
            enrolledLoad.StudyLoadID,
            new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Pending });
        Assert.IsType<BadRequestObjectResult>(badPending);
    }
}
