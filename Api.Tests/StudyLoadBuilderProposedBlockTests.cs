using Api.Auth;
using Api.Common;
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

public class StudyLoadBuilderProposedBlockTests : IDisposable
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

    public StudyLoadBuilderProposedBlockTests()
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

        _program = new AcademicProgram { ProgramID = 10, ProgramCode = "BSIT", ProgramName = "Information Technology" };
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

        return new ActionExecutingContext(
            new ActionContext(httpContext, new RouteData(), new ActionDescriptor()),
            new List<IFilterMetadata>(),
            new Dictionary<string, object?>(),
            new Mock<Controller>().Object);
    }

    private async Task<User> CreateStaffUserAsync(string email, int role)
    {
        var user = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = Guid.NewGuid().ToString(),
            Email = email,
            Role = role,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    private async Task<(User User, UserDetails Details)> CreateStudentAsync(string email, int yearLevel = 1)
    {
        var user = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = Guid.NewGuid().ToString(),
            Email = email,
            Role = RoleUtils.Student,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };
        var details = new UserDetails
        {
            UserID = user.UserID,
            Firstname = "Student",
            Lastname = "User",
            ProgramID = _program.ProgramID,
            YearLevel = yearLevel
        };
        _context.Users.Add(user);
        _context.UserDetails.Add(details);
        await _context.SaveChangesAsync();
        return (user, details);
    }

    private async Task<(Subject Subject, Class Class)> CreateSubjectAndClassAsync(
        string code,
        string title,
        int yearLevel = 1,
        int defaultSemester = 1,
        decimal lecUnits = 3m,
        decimal labUnits = 0m,
        int? standingYear = null,
        bool createClass = true,
        AcademicTerm? term = null)
    {
        var subject = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = code,
            SubjectTitle = title,
            ProgramID = _program.ProgramID,
            YearLevel = yearLevel,
            DefaultSemester = defaultSemester,
            LecUnits = lecUnits,
            LabUnits = labUnits,
            StandingYear = standingYear
        };
        _context.Subjects.Add(subject);

        Class? cls = null;
        if (createClass)
        {
            var targetTerm = term ?? _term;
            cls = new Class
            {
                ClassID = Guid.NewGuid(),
                SubjectID = subject.SubjectID,
                TermID = targetTerm.TermID,
                ClassName = $"{code}-SEC1",
                CreatedAt = DateTime.UtcNow
            };
            _context.Classes.Add(cls);
        }

        await _context.SaveChangesAsync();
        return (subject, cls!);
    }

    [Fact]
    public async Task GetProposedBlock_RegularOnly_ForCleanStudentRecord()
    {
        var (student, _) = await CreateStudentAsync("clean_student@dbtc-cebu.edu.ph", yearLevel: 2);
        var priorTerm = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };
        _context.AcademicTerms.Add(priorTerm);

        // Year 1 subject, passed in prior term
        var (y1Subject, y1Class) = await CreateSubjectAndClassAsync("Y1_SUBJ", "Year 1 Subject", yearLevel: 1, defaultSemester: 1, term: priorTerm);
        var y1Load = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = y1Class.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(y1Load);
        _context.Grades.Add(new Grade
        {
            GradeID = Guid.NewGuid(),
            StudyLoadID = y1Load.StudyLoadID,
            FinalGrade = 2.0m, // Real scale passing grade
            Remarks = 1 // Passed
        });

        // Year 2 Sem 1 subject (current term)
        var (y2Subject, y2Class) = await CreateSubjectAndClassAsync("Y2_SUBJ", "Year 2 Subject", yearLevel: 2, defaultSemester: 1, term: _term);

        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);

        // Only Year 2 regular subject appears; Year 1 passed subject does not appear!
        Assert.Single(block);
        var item = block[0];
        Assert.Equal("regular", item.Category);
        Assert.Equal(y2Subject.SubjectID, item.SubjectId);
        Assert.False(item.AlreadyPassed);
    }

    [Fact]
    public async Task GetProposedBlock_FailedSubject_BecomesRetakeWithLastGrade_DisappearsOncePassed()
    {
        var (student, _) = await CreateStudentAsync("retake_student@dbtc-cebu.edu.ph", yearLevel: 2);
        var priorTerm = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };
        _context.AcademicTerms.Add(priorTerm);

        var (failedSubj, failedClass) = await CreateSubjectAndClassAsync("MATH201", "Calculus", yearLevel: 1, defaultSemester: 1, term: priorTerm);
        var failedLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = failedClass.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(failedLoad);
        _context.Grades.Add(new Grade
        {
            GradeID = Guid.NewGuid(),
            StudyLoadID = failedLoad.StudyLoadID,
            FinalGrade = 5.0m, // Real Philippine scale failing grade
            Remarks = 2 // Failed
        });
        await _context.SaveChangesAsync();

        // 1. Check: Subject appears as "retake" with LastGrade 5.0 and LastGradeTerm
        var block1 = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);
        var retakeItem = block1.FirstOrDefault(b => b.SubjectId == failedSubj.SubjectID);
        Assert.NotNull(retakeItem);
        Assert.Equal("retake", retakeItem.Category);
        Assert.Equal(5.0m, retakeItem.LastGrade);
        Assert.Equal("2025-2026 (1st Sem)", retakeItem.LastGradeTerm);

        // 2. Student retakes and passes the subject later with real passing grade (2.0)
        var retakeTerm = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 2, IsActive = false };
        _context.AcademicTerms.Add(retakeTerm);
        var passedClass = new Class
        {
            ClassID = Guid.NewGuid(),
            SubjectID = failedSubj.SubjectID,
            TermID = retakeTerm.TermID,
            ClassName = "MATH201-SEC2",
            CreatedAt = DateTime.UtcNow
        };
        _context.Classes.Add(passedClass);
        var passedLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = passedClass.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(passedLoad);
        _context.Grades.Add(new Grade
        {
            GradeID = Guid.NewGuid(),
            StudyLoadID = passedLoad.StudyLoadID,
            FinalGrade = 2.0m, // Real Philippine scale passing grade
            Remarks = 1 // Passed
        });
        await _context.SaveChangesAsync();

        // 3. Check: Once passed, it disappears from the proposed block!
        var block2 = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);
        var disappearedItem = block2.FirstOrDefault(b => b.SubjectId == failedSubj.SubjectID);
        Assert.Null(disappearedItem);
    }

    [Fact]
    public async Task GetProposedBlock_StudentPassedWithRealGrades_125_200_275_300_HasZeroRetakeCandidates()
    {
        var (student, _) = await CreateStudentAsync("passed_grades_student@dbtc-cebu.edu.ph", yearLevel: 2);
        var priorTerm = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };
        _context.AcademicTerms.Add(priorTerm);

        // Seed 4 subjects passed on the real Philippine scale: 1.25, 2.0, 2.75, 3.0
        var grades = new[] { 1.25m, 2.0m, 2.75m, 3.0m };
        for (int i = 0; i < grades.Length; i++)
        {
            var (s, c) = await CreateSubjectAndClassAsync($"PASS{i + 1}", $"Passed Subject {i + 1}", yearLevel: 1, defaultSemester: 1, term: priorTerm);
            var sl = new StudyLoad
            {
                StudyLoadID = Guid.NewGuid(),
                UserID = student.UserID,
                ClassID = c.ClassID,
                LoadStatus = StudyLoadStatus.Enrolled,
                CreatedAt = DateTime.UtcNow
            };
            _context.StudyLoads.Add(sl);
            _context.Grades.Add(new Grade
            {
                GradeID = Guid.NewGuid(),
                StudyLoadID = sl.StudyLoadID,
                FinalGrade = grades[i],
                Remarks = 1 // Passed
            });
        }
        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);
        var retakeCandidates = block.Where(b => b.Category == "retake").ToList();
        Assert.Empty(retakeCandidates);
    }

    [Fact]
    public async Task GetProposedBlock_FailedTwiceThenPassed_NotRetake()
    {
        var (student, _) = await CreateStudentAsync("failed_twice_passed@dbtc-cebu.edu.ph", yearLevel: 2);
        var term1 = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2024-2025", Semester = 1, IsActive = false };
        var term2 = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2024-2025", Semester = 2, IsActive = false };
        var term3 = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };
        _context.AcademicTerms.AddRange(term1, term2, term3);

        var (subj, class1) = await CreateSubjectAndClassAsync("HARD101", "Hard Subject", yearLevel: 1, defaultSemester: 1, term: term1);
        var class2 = new Class { ClassID = Guid.NewGuid(), SubjectID = subj.SubjectID, TermID = term2.TermID, ClassName = "HARD101-T2", CreatedAt = DateTime.UtcNow };
        var class3 = new Class { ClassID = Guid.NewGuid(), SubjectID = subj.SubjectID, TermID = term3.TermID, ClassName = "HARD101-T3", CreatedAt = DateTime.UtcNow };
        _context.Classes.AddRange(class2, class3);

        // Attempt 1: Failed with 5.0
        var sl1 = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = student.UserID, ClassID = class1.ClassID, LoadStatus = StudyLoadStatus.Enrolled, CreatedAt = DateTime.UtcNow };
        // Attempt 2: Failed with 5.0
        var sl2 = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = student.UserID, ClassID = class2.ClassID, LoadStatus = StudyLoadStatus.Enrolled, CreatedAt = DateTime.UtcNow };
        // Attempt 3: Passed with 3.0
        var sl3 = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = student.UserID, ClassID = class3.ClassID, LoadStatus = StudyLoadStatus.Enrolled, CreatedAt = DateTime.UtcNow };
        _context.StudyLoads.AddRange(sl1, sl2, sl3);

        _context.Grades.AddRange(
            new Grade { GradeID = Guid.NewGuid(), StudyLoadID = sl1.StudyLoadID, FinalGrade = 5.0m, Remarks = 2 },
            new Grade { GradeID = Guid.NewGuid(), StudyLoadID = sl2.StudyLoadID, FinalGrade = 5.0m, Remarks = 2 },
            new Grade { GradeID = Guid.NewGuid(), StudyLoadID = sl3.StudyLoadID, FinalGrade = 3.0m, Remarks = 1 }
        );
        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);
        var item = block.FirstOrDefault(b => b.SubjectId == subj.SubjectID);
        Assert.Null(item); // Passed subject disappears, not a retake!
    }

    [Fact]
    public async Task GetProposedBlock_PendingRejectedDropped_NeverCountAsPassedOrFailed()
    {
        var (student, _) = await CreateStudentAsync("academic_evidence_status@dbtc-cebu.edu.ph", yearLevel: 2);
        var priorTerm = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };
        _context.AcademicTerms.Add(priorTerm);

        // Subj1: has a Pending load
        var (subjPending, classPending) = await CreateSubjectAndClassAsync("SUBJ_PEND", "Pending Subject", yearLevel: 1, defaultSemester: 1, term: priorTerm);
        // Subj2: has a Rejected load
        var (subjRejected, classRejected) = await CreateSubjectAndClassAsync("SUBJ_REJ", "Rejected Subject", yearLevel: 1, defaultSemester: 1, term: priorTerm);
        // Subj3: has a Dropped load with Remarks=2 (failing grade entered before drop)
        var (subjDropped, classDropped) = await CreateSubjectAndClassAsync("SUBJ_DROP", "Dropped Subject", yearLevel: 1, defaultSemester: 1, term: priorTerm);

        var slPending = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = student.UserID, ClassID = classPending.ClassID, LoadStatus = StudyLoadStatus.Pending, CreatedAt = DateTime.UtcNow };
        var slRejected = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = student.UserID, ClassID = classRejected.ClassID, LoadStatus = StudyLoadStatus.Rejected, CreatedAt = DateTime.UtcNow };
        var slDropped = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = student.UserID, ClassID = classDropped.ClassID, LoadStatus = StudyLoadStatus.Dropped, CreatedAt = DateTime.UtcNow };
        _context.StudyLoads.AddRange(slPending, slRejected, slDropped);

        // Add a grade to the dropped load to verify it is NEVER counted as academic evidence of failure
        _context.Grades.Add(new Grade { GradeID = Guid.NewGuid(), StudyLoadID = slDropped.StudyLoadID, FinalGrade = 5.0m, Remarks = 2 });
        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);

        // None of these should be "retake"
        var retakes = block.Where(b => b.Category == "retake").ToList();
        Assert.Empty(retakes);

        // All earlier-year subjects should be categorized as back_subject (never passed or counted as failed)
        var itemPending = block.FirstOrDefault(b => b.SubjectId == subjPending.SubjectID);
        var itemRejected = block.FirstOrDefault(b => b.SubjectId == subjRejected.SubjectID);
        var itemDropped = block.FirstOrDefault(b => b.SubjectId == subjDropped.SubjectID);

        Assert.NotNull(itemPending);
        Assert.Equal("back_subject", itemPending.Category);

        Assert.NotNull(itemRejected);
        Assert.Equal("back_subject", itemRejected.Category);

        Assert.NotNull(itemDropped);
        Assert.Equal("back_subject", itemDropped.Category);
    }

    [Fact]
    public async Task GetProposedBlock_CurrentlyEnrolledWithNoFinalGrade_InProgress_NotRetakeOrBackSubject()
    {
        var (student, _) = await CreateStudentAsync("in_progress_student@dbtc-cebu.edu.ph", yearLevel: 2);
        var priorTerm = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };
        _context.AcademicTerms.Add(priorTerm);

        // Earlier-year subject currently Enrolled with NO final grade
        var (inProgressSubj, inProgressClass) = await CreateSubjectAndClassAsync("INPROG101", "In Progress Subject", yearLevel: 1, defaultSemester: 1, term: priorTerm);
        var sl = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = inProgressClass.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(sl);
        // No grade record added (or Remarks null)
        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);

        // In progress: must NOT be retake, and must NOT be back_subject
        var item = block.FirstOrDefault(b => b.SubjectId == inProgressSubj.SubjectID);
        Assert.Null(item);
    }

    [Fact]
    public async Task GetProposedBlock_EarlierSemesterOfSameYear_NeverTaken_BecomesBackSubject_AndSummerCounts()
    {
        var (student, _) = await CreateStudentAsync("same_year_earlier_sem@dbtc-cebu.edu.ph", yearLevel: 2);

        // Case 1: Term is 2nd Semester (Semester = 2), Student is Year 2
        var sem2Term = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 2, IsActive = true };
        _context.AcademicTerms.Add(sem2Term);

        // Subject is Year 2, Semester 1 (never taken)
        var (sem1Subj, _) = await CreateSubjectAndClassAsync("Y2S1_SUBJ", "Year 2 Sem 1 Subject", yearLevel: 2, defaultSemester: 1, term: sem2Term);
        // Subject is Year 2, Semester 2 (regular for sem 2)
        var (sem2Subj, _) = await CreateSubjectAndClassAsync("Y2S2_SUBJ", "Year 2 Sem 2 Subject", yearLevel: 2, defaultSemester: 2, term: sem2Term);
        await _context.SaveChangesAsync();

        var blockSem2 = await _studyLoadService.GetProposedBlockAsync(student.UserID, sem2Term.TermID);

        var itemSem1 = blockSem2.FirstOrDefault(b => b.SubjectId == sem1Subj.SubjectID);
        var itemSem2 = blockSem2.FirstOrDefault(b => b.SubjectId == sem2Subj.SubjectID);

        Assert.NotNull(itemSem1);
        Assert.Equal("back_subject", itemSem1.Category); // Earlier semester of same year is back_subject!

        Assert.NotNull(itemSem2);
        Assert.Equal("regular", itemSem2.Category); // Same semester of same year is regular!

        // Case 2: Summer term (Semester = 3)
        var summerTerm = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 3, IsActive = true };
        _context.AcademicTerms.Add(summerTerm);
        await _context.SaveChangesAsync();

        var blockSummer = await _studyLoadService.GetProposedBlockAsync(student.UserID, summerTerm.TermID);
        var itemSummerSem1 = blockSummer.FirstOrDefault(b => b.SubjectId == sem1Subj.SubjectID);
        var itemSummerSem2 = blockSummer.FirstOrDefault(b => b.SubjectId == sem2Subj.SubjectID);

        Assert.NotNull(itemSummerSem1);
        Assert.Equal("back_subject", itemSummerSem1.Category); // Sem 1 is back_subject in summer

        Assert.NotNull(itemSummerSem2);
        Assert.Equal("back_subject", itemSummerSem2.Category); // Sem 2 is back_subject in summer
    }

    [Fact]
    public async Task GetProposedBlock_EarlierYearSubject_NeverTaken_BecomesBackSubject_PassedOneDoesNotAppear()
    {
        var (student, _) = await CreateStudentAsync("back_subj_student@dbtc-cebu.edu.ph", yearLevel: 2);
        var priorTerm = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };
        _context.AcademicTerms.Add(priorTerm);

        // Earlier year subject 1: never taken
        var (backSubj, _) = await CreateSubjectAndClassAsync("BACK101", "Back Subject 1", yearLevel: 1, defaultSemester: 1);

        // Earlier year subject 2: passed with real passing grade (1.5)
        var (passedSubj, passedClass) = await CreateSubjectAndClassAsync("PASSED101", "Passed Subject", yearLevel: 1, defaultSemester: 1, term: priorTerm);
        var pLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = passedClass.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(pLoad);
        _context.Grades.Add(new Grade
        {
            GradeID = Guid.NewGuid(),
            StudyLoadID = pLoad.StudyLoadID,
            FinalGrade = 1.5m, // Real scale passed
            Remarks = 1 // Passed
        });
        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);

        // backSubj must appear as "back_subject"
        var backItem = block.FirstOrDefault(b => b.SubjectId == backSubj.SubjectID);
        Assert.NotNull(backItem);
        Assert.Equal("back_subject", backItem.Category);

        // passedSubj must NOT appear
        var passedItem = block.FirstOrDefault(b => b.SubjectId == passedSubj.SubjectID);
        Assert.Null(passedItem);
    }

    [Fact]
    public async Task GetProposedBlock_RejectedOrPendingLoad_DoesNotCountAsTaken()
    {
        var (student, _) = await CreateStudentAsync("rejected_pending_test@dbtc-cebu.edu.ph", yearLevel: 2);
        var (earlierSubj, earlierClass) = await CreateSubjectAndClassAsync("EARLY101", "Early Subject", yearLevel: 1, defaultSemester: 1);

        // Seed a Rejected study load
        _context.StudyLoads.Add(new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = earlierClass.ClassID,
            LoadStatus = StudyLoadStatus.Rejected,
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);
        var item = block.FirstOrDefault(b => b.SubjectId == earlierSubj.SubjectID);

        // Rejected load does not count as taken, so earlier-year subject remains back_subject!
        Assert.NotNull(item);
        Assert.Equal("back_subject", item.Category);
    }

    [Fact]
    public async Task GetProposedBlock_StandingStatus_MetUnmetNotRequired_And_CorequisitePairing()
    {
        var (student, _) = await CreateStudentAsync("standing_coreq@dbtc-cebu.edu.ph", yearLevel: 2);

        // 1. Standing checks
        var (subjNotRequired, _) = await CreateSubjectAndClassAsync("STAND_NONE", "No Standing", yearLevel: 2, defaultSemester: 1, standingYear: null);
        var (subjMet, _) = await CreateSubjectAndClassAsync("STAND_MET", "Standing Met", yearLevel: 2, defaultSemester: 1, standingYear: 2);
        var (subjUnmet, _) = await CreateSubjectAndClassAsync("STAND_UNMET", "Standing Unmet", yearLevel: 2, defaultSemester: 1, standingYear: 3);

        // 2. Corequisite pairing: Lecture and Lab
        var (lecSubj, _) = await CreateSubjectAndClassAsync("CS101", "Intro CS Lec", yearLevel: 2, defaultSemester: 1);
        var (labSubj, _) = await CreateSubjectAndClassAsync("CS101L", "Intro CS Lab", yearLevel: 2, defaultSemester: 1);

        _context.SubjectPrerequisites.Add(new SubjectPrerequisite
        {
            PrerequisiteID = Guid.NewGuid(),
            SubjectID = lecSubj.SubjectID,
            PrerequisiteSubjectID = labSubj.SubjectID,
            RequisiteType = RequisiteTypeConstants.Corequisite
        });
        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);

        var itemNone = block.First(b => b.SubjectId == subjNotRequired.SubjectID);
        var itemMet = block.First(b => b.SubjectId == subjMet.SubjectID);
        var itemUnmet = block.First(b => b.SubjectId == subjUnmet.SubjectID);

        Assert.Equal("not_required", itemNone.StandingStatus);
        Assert.Equal("met", itemMet.StandingStatus);
        Assert.Equal("unmet", itemUnmet.StandingStatus);

        // Corequisite pairing: Lecture lists Lab, Lab lists Lecture
        var itemLec = block.First(b => b.SubjectId == lecSubj.SubjectID);
        var itemLab = block.First(b => b.SubjectId == labSubj.SubjectID);

        Assert.Single(itemLec.Corequisites);
        Assert.Equal(labSubj.SubjectID, itemLec.Corequisites[0].SubjectId);
        Assert.Equal("CS101L", itemLec.Corequisites[0].SubjectCode);
        Assert.True(itemLec.Corequisites[0].IncludedInProposal);

        Assert.Single(itemLab.Corequisites);
        Assert.Equal(lecSubj.SubjectID, itemLab.Corequisites[0].SubjectId);
        Assert.Equal("CS101", itemLab.Corequisites[0].SubjectCode);
        Assert.True(itemLab.Corequisites[0].IncludedInProposal);
    }

    [Fact]
    public async Task GetProposedBlock_NoClassOffered_ReturnedButFlagged()
    {
        var (student, _) = await CreateStudentAsync("no_class_student@dbtc-cebu.edu.ph", yearLevel: 1);

        // Create subject with NO class created in current term
        var (subjNoClass, _) = await CreateSubjectAndClassAsync("RARE101", "Rare Subject", yearLevel: 1, defaultSemester: 1, createClass: false);

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);
        var item = block.FirstOrDefault(b => b.SubjectId == subjNoClass.SubjectID);

        Assert.NotNull(item);
        Assert.Equal("no_class_offered", item.MatchType);
        Assert.Null(item.ClassId);
    }

    [Fact]
    public async Task GetProposedBlock_FailedPrerequisite_MakesDependentsUnmet_WithRealMessage()
    {
        var (student, _) = await CreateStudentAsync("prereq_fail_student@dbtc-cebu.edu.ph", yearLevel: 2);
        var priorTerm = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };
        _context.AcademicTerms.Add(priorTerm);

        var (prereqSubj, prereqClass) = await CreateSubjectAndClassAsync("PREREQ_A", "Prereq Subject A", yearLevel: 1, defaultSemester: 1, term: priorTerm);
        var (targetSubj, _) = await CreateSubjectAndClassAsync("TARGET_B", "Target Subject B", yearLevel: 2, defaultSemester: 1);

        _context.SubjectPrerequisites.Add(new SubjectPrerequisite
        {
            PrerequisiteID = Guid.NewGuid(),
            SubjectID = targetSubj.SubjectID,
            PrerequisiteSubjectID = prereqSubj.SubjectID,
            RequisiteType = RequisiteTypeConstants.Prerequisite
        });

        // Seed a failed grade on prereqSubj
        var load = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = prereqClass.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(load);
        _context.Grades.Add(new Grade
        {
            GradeID = Guid.NewGuid(),
            StudyLoadID = load.StudyLoadID,
            FinalGrade = 5.0m, // Real scale failing grade
            Remarks = 2 // Failed
        });
        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);
        var itemB = block.First(b => b.SubjectId == targetSubj.SubjectID);

        Assert.Equal("unmet", itemB.PrerequisiteStatus);
        Assert.Single(itemB.PrerequisiteMessages);
        Assert.Contains("PREREQ_A", itemB.PrerequisiteMessages[0]);
        Assert.Contains("failed, last grade 5.0", itemB.PrerequisiteMessages[0]);
    }

    [Fact]
    public async Task GetProposedBlock_ImportedBsitData_Prereq0Coreq1_ReadCorrectly()
    {
        var (student, _) = await CreateStudentAsync("bsit_curric_student@dbtc-cebu.edu.ph", yearLevel: 2);
        var (prereqSubj, _) = await CreateSubjectAndClassAsync("IT111", "Programming 1", yearLevel: 1, defaultSemester: 1);
        var (lecSubj, _) = await CreateSubjectAndClassAsync("IT211", "Data Structures Lec", yearLevel: 2, defaultSemester: 1);
        var (labSubj, _) = await CreateSubjectAndClassAsync("IT211L", "Data Structures Lab", yearLevel: 2, defaultSemester: 1);

        // IT211 has Prerequisite IT111 (Type 0)
        _context.SubjectPrerequisites.Add(new SubjectPrerequisite
        {
            PrerequisiteID = Guid.NewGuid(),
            SubjectID = lecSubj.SubjectID,
            PrerequisiteSubjectID = prereqSubj.SubjectID,
            RequisiteType = RequisiteTypeConstants.Prerequisite // 0
        });

        // IT211 has Corequisite IT211L (Type 1)
        _context.SubjectPrerequisites.Add(new SubjectPrerequisite
        {
            PrerequisiteID = Guid.NewGuid(),
            SubjectID = lecSubj.SubjectID,
            PrerequisiteSubjectID = labSubj.SubjectID,
            RequisiteType = RequisiteTypeConstants.Corequisite // 1
        });
        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, _term.TermID);
        var it211 = block.First(b => b.SubjectId == lecSubj.SubjectID);

        // Prerequisite (Type 0) went to PrerequisiteMessages
        Assert.Equal("unmet", it211.PrerequisiteStatus);
        Assert.Contains(it211.PrerequisiteMessages, m => m.Contains("IT111"));

        // Corequisite (Type 1) went to Corequisites list, NOT PrerequisiteMessages
        Assert.Single(it211.Corequisites);
        Assert.Equal("IT211L", it211.Corequisites[0].SubjectCode);
        Assert.DoesNotContain(it211.PrerequisiteMessages, m => m.Contains("IT211L"));
    }

    [Fact]
    public async Task GetProposedBlock_RoleMatrix_RegistrarAdminCollegeHead200_TeacherStudentProgramHead403()
    {
        var registrar = await CreateStaffUserAsync("reg_rm@dbtc-cebu.edu.ph", RoleUtils.Registrar);
        var admin = await CreateStaffUserAsync("adm_rm@dbtc-cebu.edu.ph", RoleUtils.Admin);
        var collegeHead = await CreateStaffUserAsync("ch_rm@dbtc-cebu.edu.ph", RoleUtils.CollegeHead);
        var teacher = await CreateStaffUserAsync("tch_rm@dbtc-cebu.edu.ph", RoleUtils.Teacher);
        var studentUser = await CreateStaffUserAsync("std_rm@dbtc-cebu.edu.ph", RoleUtils.Student);
        var progHead = await CreateStaffUserAsync("ph_rm@dbtc-cebu.edu.ph", RoleUtils.ProgramHead);

        var (student, _) = await CreateStudentAsync("target_rm@dbtc-cebu.edu.ph", yearLevel: 1);
        await CreateSubjectAndClassAsync("TEST101", "Test Subject", yearLevel: 1, defaultSemester: 1);

        var filter = new RequireRegistrarCollegeHeadOrAdminAttribute();

        // 1. Registrar allowed
        var regCtx = CreateFilterContext(registrar.UserID, _userRepo);
        await filter.OnActionExecutionAsync(regCtx, () => Task.FromResult(new ActionExecutedContext(regCtx, new List<IFilterMetadata>(), new Mock<Controller>().Object)));
        Assert.Null(regCtx.Result);

        // 2. Admin allowed
        var admCtx = CreateFilterContext(admin.UserID, _userRepo);
        await filter.OnActionExecutionAsync(admCtx, () => Task.FromResult(new ActionExecutedContext(admCtx, new List<IFilterMetadata>(), new Mock<Controller>().Object)));
        Assert.Null(admCtx.Result);

        // 3. College Head allowed
        var chCtx = CreateFilterContext(collegeHead.UserID, _userRepo);
        await filter.OnActionExecutionAsync(chCtx, () => Task.FromResult(new ActionExecutedContext(chCtx, new List<IFilterMetadata>(), new Mock<Controller>().Object)));
        Assert.Null(chCtx.Result);

        // 4. Teacher denied (403)
        var tchCtx = CreateFilterContext(teacher.UserID, _userRepo);
        await filter.OnActionExecutionAsync(tchCtx, () => Task.FromResult(new ActionExecutedContext(tchCtx, new List<IFilterMetadata>(), new Mock<Controller>().Object)));
        var tchRes = Assert.IsType<ObjectResult>(tchCtx.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, tchRes.StatusCode);

        // 5. Student denied (403)
        var stdCtx = CreateFilterContext(studentUser.UserID, _userRepo);
        await filter.OnActionExecutionAsync(stdCtx, () => Task.FromResult(new ActionExecutedContext(stdCtx, new List<IFilterMetadata>(), new Mock<Controller>().Object)));
        var stdRes = Assert.IsType<ObjectResult>(stdCtx.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, stdRes.StatusCode);

        // 6. Program Head denied (403)
        var phCtx = CreateFilterContext(progHead.UserID, _userRepo);
        await filter.OnActionExecutionAsync(phCtx, () => Task.FromResult(new ActionExecutedContext(phCtx, new List<IFilterMetadata>(), new Mock<Controller>().Object)));
        var phRes = Assert.IsType<ObjectResult>(phCtx.Result);
        Assert.Equal(StatusCodes.Status403Forbidden, phRes.StatusCode);
    }

    [Fact]
    public async Task GetByClass_ClassRosters_HideRejectedLoadsByDefault_VisibleInStudentHistory()
    {
        var (s1, _) = await CreateStudentAsync("s1_roster@dbtc-cebu.edu.ph", yearLevel: 1);
        var (s2, _) = await CreateStudentAsync("s2_roster@dbtc-cebu.edu.ph", yearLevel: 1);
        var (s3, _) = await CreateStudentAsync("s3_roster@dbtc-cebu.edu.ph", yearLevel: 1);

        var (_, cls) = await CreateSubjectAndClassAsync("ROSTER101", "Roster Subject", yearLevel: 1, defaultSemester: 1);

        // Seed 1 Enrolled, 1 Pending, 1 Rejected load
        _context.StudyLoads.AddRange(
            new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = s1.UserID, ClassID = cls.ClassID, LoadStatus = StudyLoadStatus.Enrolled, CreatedAt = DateTime.UtcNow },
            new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = s2.UserID, ClassID = cls.ClassID, LoadStatus = StudyLoadStatus.Pending, CreatedAt = DateTime.UtcNow },
            new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = s3.UserID, ClassID = cls.ClassID, LoadStatus = StudyLoadStatus.Rejected, CreatedAt = DateTime.UtcNow }
        );
        await _context.SaveChangesAsync();

        // 1. Registrar view of class roster: shows Enrolled and Pending, hides Rejected!
        var regRoster = await _studyLoadService.GetByClassAsync(cls.ClassID, excludePending: false, callerRole: RoleUtils.Registrar);
        Assert.Equal(2, regRoster.Count);
        Assert.DoesNotContain(regRoster, r => r.StudentUserId == s3.UserID || r.LoadStatus == "Rejected");

        // 2. Program Head view of class roster: shows Enrolled and Pending, hides Rejected!
        var phRoster = await _studyLoadService.GetByClassAsync(cls.ClassID, excludePending: false, callerRole: RoleUtils.ProgramHead);
        Assert.Equal(2, phRoster.Count);
        Assert.DoesNotContain(phRoster, r => r.StudentUserId == s3.UserID || r.LoadStatus == "Rejected");

        // 3. Teacher view of class roster: hides Pending and Rejected!
        var tchRoster = await _studyLoadService.GetByClassAsync(cls.ClassID, excludePending: true, callerRole: RoleUtils.Teacher);
        Assert.Single(tchRoster);
        Assert.Equal(s1.UserID, tchRoster[0].StudentUserId);

        // 4. Student's own study load history: Rejected load remains visible!
        var studentLoads = await _studyLoadService.GetByStudentAsync(s3.UserID, _term.TermID);
        Assert.Single(studentLoads);
        Assert.Equal("Rejected", studentLoads[0].LoadStatus);
    }

    [Fact]
    public async Task GetProposedBlock_Returns_Three_Categories_Regular_Retake_BackSubject()
    {
        // Student is 2nd Year in Semester 2 term
        var termSem2 = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2026-2027", Semester = 2, IsActive = true };
        _context.AcademicTerms.Add(termSem2);

        var (student, _) = await CreateStudentAsync("three_categories@dbtc-cebu.edu.ph", yearLevel: 2);

        // 1. Regular: 2nd Year Sem 2 subject
        var (regularSubj, regularClass) = await CreateSubjectAndClassAsync("CS221", "Software Engineering", yearLevel: 2, defaultSemester: 2, term: termSem2);

        // 2. Retake: 1st Year Sem 1 subject failed with 5.0 in prior term
        var priorTerm = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };
        _context.AcademicTerms.Add(priorTerm);
        var (retakeSubj, priorTermClass) = await CreateSubjectAndClassAsync("CS111", "Programming 1", yearLevel: 1, defaultSemester: 1, term: priorTerm);
        var retakeClassThisTerm = new Class { ClassID = Guid.NewGuid(), SubjectID = retakeSubj.SubjectID, TermID = termSem2.TermID, ClassName = "CS111-RET" };
        _context.Classes.Add(retakeClassThisTerm);

        var failedLoad = new StudyLoad
        {
            StudyLoadID = Guid.NewGuid(),
            UserID = student.UserID,
            ClassID = priorTermClass.ClassID,
            LoadStatus = StudyLoadStatus.Enrolled,
            CreatedAt = DateTime.UtcNow
        };
        _context.StudyLoads.Add(failedLoad);
        _context.Grades.Add(new Grade
        {
            GradeID = Guid.NewGuid(),
            StudyLoadID = failedLoad.StudyLoadID,
            FinalGrade = 5.0m,
            Remarks = 2 // Failed
        });

        // 3. Back Subject: 2nd Year Sem 1 subject never taken
        var (backSubj, backClass) = await CreateSubjectAndClassAsync("CS211", "Data Structures", yearLevel: 2, defaultSemester: 1, term: termSem2);

        await _context.SaveChangesAsync();

        var block = await _studyLoadService.GetProposedBlockAsync(student.UserID, termSem2.TermID);

        var regularItem = block.FirstOrDefault(b => b.SubjectId == regularSubj.SubjectID);
        var retakeItem = block.FirstOrDefault(b => b.SubjectId == retakeSubj.SubjectID);
        var backItem = block.FirstOrDefault(b => b.SubjectId == backSubj.SubjectID);

        Assert.NotNull(regularItem);
        Assert.Equal("regular", regularItem.Category);

        Assert.NotNull(retakeItem);
        Assert.Equal("retake", retakeItem.Category);
        Assert.Equal(5.0m, retakeItem.LastGrade);

        Assert.NotNull(backItem);
        Assert.Equal("back_subject", backItem.Category);

        var json = System.Text.Json.JsonSerializer.Serialize(block, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
        Assert.NotEmpty(json);
    }
}
