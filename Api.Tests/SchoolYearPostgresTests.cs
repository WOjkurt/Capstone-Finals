using Api.Auth;
using Api.Controllers;
using Api.Domain.Audit;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Credits;
using Api.DTOs.Enrollment;
using Api.DTOs.Grading;
using Api.DTOs.Records;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Api.Tests;

/// <summary>Runs only when TEST_POSTGRES holds a connection string to a throwaway, migrated database.</summary>
public sealed class PostgresFactAttribute : FactAttribute
{
    public PostgresFactAttribute()
    {
        if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("TEST_POSTGRES")))
            Skip = "Set TEST_POSTGRES to run against a real PostgreSQL database.";
    }
}

/// <summary>
/// One student through a whole school year on real PostgreSQL, with a fresh DbContext per step as in real
/// requests. The in-memory database used by the other tests cannot catch query translation, transaction or
/// constraint problems; this does. Never point TEST_POSTGRES at a database you care about.
/// </summary>
public class SchoolYearPostgresTests
{
    private readonly ServiceProvider _root;
    private readonly string _tag = Guid.NewGuid().ToString("N")[..8];
    private readonly Guid _registrar = Guid.NewGuid(), _collegeHead = Guid.NewGuid(), _teacher = Guid.NewGuid(), _student = Guid.NewGuid();
    private readonly Guid _term1 = Guid.NewGuid(), _term2 = Guid.NewGuid();
    private int _program, _otherProgram;
    private readonly Dictionary<string, Guid> _subject = new();
    private readonly Dictionary<(string Code, Guid Term), Guid> _class = new();

    public SchoolYearPostgresTests()
    {
        var conn = Environment.GetEnvironmentVariable("TEST_POSTGRES");
        var s = new ServiceCollection();
        s.AddLogging();
        s.AddDbContext<AppDbContext>(o => o.UseNpgsql(conn ?? "Host=none"));
        s.AddScoped<IUserRepository, UserRepository>();
        s.AddScoped<IUserDetailsRepository, UserDetailsRepository>();
        s.AddScoped<IEnrollmentResponseRepository, EnrollmentResponseRepository>();
        s.AddScoped<IEnrollmentApplicationRepository, EnrollmentApplicationRepository>();
        s.AddScoped<IEnrollmentFormRepository, EnrollmentFormRepository>();
        s.AddScoped<IContactRepository, ContactRepository>();
        s.AddScoped<IClassRepository, ClassRepository>();
        s.AddScoped<IStudyLoadRepository, StudyLoadRepository>();
        s.AddScoped<IGradeRepository, GradeRepository>();
        s.AddScoped<IGradeCorrectionRepository, GradeCorrectionRepository>();
        s.AddScoped<IGradeClearanceRepository, GradeClearanceRepository>();
        s.AddScoped<IEnrollmentService, EnrollmentService>();
        s.AddScoped<ICreditedSubjectService, CreditedSubjectService>();
        s.AddScoped<IReportService, ReportService>();
        s.AddScoped<IStudentRecordService, StudentRecordService>();
        s.AddScoped<IAccreditedSchoolService, AccreditedSchoolService>();
        s.AddScoped<IStudyLoadChangeService, StudyLoadChangeService>();
        s.AddScoped<IActivityLogService, ActivityLogService>();
        s.AddScoped<IStudyLoadService, StudyLoadService>();
        s.AddScoped<IGradeService, GradeService>();
        s.AddScoped<IGradeCorrectionService, GradeCorrectionService>();
        s.AddScoped<IGradeClearanceService, GradeClearanceService>();
        s.AddScoped<IProgramScopingService, ProgramScopingService>();
        _root = s.BuildServiceProvider();
    }

    private async Task<T> Step<T>(Func<IServiceProvider, Task<T>> work)
    {
        using var scope = _root.CreateScope();
        return await work(scope.ServiceProvider);
    }

    private Task Step(Func<IServiceProvider, Task> work) => Step<object?>(async sp => { await work(sp); return null; });

    private static T Svc<T>(IServiceProvider sp) where T : notnull => sp.GetRequiredService<T>();

    private static TC As<TC>(IServiceProvider sp, TC controller, Guid user, int role) where TC : ControllerBase
    {
        var http = new DefaultHttpContext { RequestServices = sp };
        http.Items["user_id"] = user;
        http.Items["role"] = role;
        controller.ControllerContext = new ControllerContext { HttpContext = http };
        return controller;
    }

    private StudyLoadsController Loads(IServiceProvider sp, Guid user, int role) =>
        As(sp, new StudyLoadsController(Svc<IStudyLoadService>(sp), Svc<IClassRepository>(sp), Svc<IUserDetailsRepository>(sp), Svc<IProgramScopingService>(sp)), user, role);

    private async Task Seed()
    {
        await Step(async sp =>
        {
            var db = Svc<AppDbContext>(sp);
            var p = new AcademicProgram { ProgramCode = "T" + _tag, ProgramName = "Test Program " + _tag };
            var q = new AcademicProgram { ProgramCode = "U" + _tag, ProgramName = "Other Program " + _tag };
            db.AcademicPrograms.AddRange(p, q);
            // Far-future years so this run's terms are the only ones near each other.
            var year = 3000 + Random.Shared.Next(0, 60000);
            db.AcademicTerms.AddRange(
                new AcademicTerm { TermID = _term1, SchoolYear = $"{year}-{year + 1}", Semester = 1 },
                new AcademicTerm { TermID = _term2, SchoolYear = $"{year}-{year + 1}", Semester = 2 });
            foreach (var (id, role, first) in new[] { (_registrar, RoleUtils.Registrar, "Rita"), (_collegeHead, RoleUtils.CollegeHead, "Carla"), (_teacher, RoleUtils.Teacher, "Ben") })
            {
                db.Users.Add(new User { UserID = id, FirebaseUID = "fb" + id, Email = id + "@test.dbtc", Role = role, IsActive = true });
                db.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = id, Firstname = first, Lastname = "Staff" });
            }
            // The student's account exists before linking: they must log in once first.
            db.Users.Add(new User { UserID = _student, FirebaseUID = "fb" + _student, Email = _student + "@student.dbtc", Role = RoleUtils.Student, IsActive = true });
            await db.SaveChangesAsync();
            _program = p.ProgramID;
            _otherProgram = q.ProgramID;

            void Add(string code, int program, int year2, int sem, bool minor = false, decimal lec = 3)
            {
                var s = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code + " title", LecUnits = lec, ProgramID = program, YearLevel = year2, DefaultSemester = sem, IsMinor = minor };
                db.Subjects.Add(s);
                _subject[program == _program ? code : "other " + code] = s.SubjectID;
            }
            foreach (var c in new[] { "MJ 101", "MJ 102", "MJ 103" }) Add(c, _program, 1, 1);
            Add("GE 101", _program, 1, 1, minor: true);
            Add("NSTP 1", _program, 1, 1, minor: true);
            Add("MJ 201", _program, 1, 2);
            foreach (var c in new[] { "MJ 202", "GE 202", "GE 203", "MJ 204" }) Add(c, _program, 1, 2, minor: c.StartsWith("GE"));
            Add("MJ 301", _program, 2, 1);
            Add("GE 101", _otherProgram, 1, 1, minor: true);   // same code in the other program, for shifting
            db.SubjectPrerequisites.Add(new SubjectPrerequisite { PrerequisiteID = Guid.NewGuid(), SubjectID = _subject["MJ 201"], PrerequisiteSubjectID = _subject["MJ 101"], RequisiteType = Api.Constants.RequisiteTypeConstants.Prerequisite });

            var hour = 7;
            foreach (var (code, term) in new[] { "MJ 101", "MJ 102", "MJ 103", "GE 101", "NSTP 1" }.Select(c => (c, _term1))
                         .Concat(new[] { "MJ 101", "MJ 102", "MJ 201", "MJ 202" }.Select(c => (c, _term2))))
            {
                var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = _subject[code], TermID = term, ClassName = "Sec " + code, UserID = _teacher, CreatedAt = DateTime.UtcNow };
                db.Classes.Add(cls);
                db.ClassSchedules.Add(new ClassSchedule { ScheduleID = Guid.NewGuid(), ClassID = cls.ClassID, DaysOfWeek = "M/W/F", StartTime = new TimeOnly(hour, 0), EndTime = new TimeOnly(hour, 50), Room = "R" + hour });
                _class[(code, term)] = cls.ClassID;
                hour = hour >= 19 ? 7 : hour + 1;
            }
            await db.SaveChangesAsync();
        });
    }

    private Task<Guid> LoadOf(string code, Guid term) => Step(sp =>
    {
        var classId = _class[(code, term)];
        return Svc<AppDbContext>(sp).StudyLoads.Where(l => l.UserID == _student && l.ClassID == classId)
            .OrderByDescending(l => l.CreatedAt).Select(l => l.StudyLoadID).FirstAsync();
    });

    private async Task Grade(string code, Guid term, decimal final)
    {
        var load = await LoadOf(code, term);
        await Step(sp => Svc<IGradeService>(sp).SubmitGradeAsync(new SubmitGradeDto { StudyLoadId = load, FinalGrade = final }, _teacher));
    }

    private async Task Admit()
    {
        await Step(async sp =>
        {
            var db = Svc<AppDbContext>(sp);
            db.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _student, Firstname = "Edge", Lastname = "Case", ProgramID = _program, YearLevel = 1 });
            await db.SaveChangesAsync();
        });
    }

    private Task<List<EnrollBatchResponseDto>> Enroll(Guid term, params string[] codes) => Step(sp => Svc<IStudyLoadService>(sp)
        .EnrollBatchAsync(new EnrollBatchRequestDto { UserId = _student, TermId = term, ClassIds = codes.Select(c => _class[(c, term)]).ToList() }, _registrar, RoleUtils.Registrar));

    private async Task Correct(string code, Guid term, decimal from, decimal to)
    {
        var grade = (await Step(sp => Svc<IGradeService>(sp).GetByStudentIdAsync(_student, term, _registrar, RoleUtils.Registrar))).Single(g => g.SubjectCode == code);
        var c = await Step(sp => Svc<IGradeCorrectionService>(sp).RequestCorrectionAsync(new CreateGradeCorrectionDto { GradeId = grade.GradeId, CorrectionPeriod = 2, OldGrade = from, NewGrade = to, Reason = "Test" }, _teacher));
        await Step(sp => Svc<IGradeCorrectionService>(sp).ApproveCorrectionAsync(c.CorrectionId, _registrar));
    }

    [PostgresFact]
    public async Task GradeCorrections_ChangePassOrFail_Everywhere()
    {
        await Seed();
        await Admit();
        await Enroll(_term1, "MJ 101", "MJ 102");
        await Grade("MJ 101", _term1, 5.0m);
        await Grade("MJ 102", _term1, 2.0m);

        await Correct("MJ 101", _term1, 5.0m, 2.25m);   // fail becomes pass
        await Correct("MJ 102", _term1, 2.0m, 5.0m);    // pass becomes fail

        var by = (await Step(sp => Svc<IStudentRecordService>(sp).GetEvaluationAsync(_student))).Subjects.ToDictionary(s => s.SubjectCode);
        Assert.Equal(("Passed", 2.25m), (by["MJ 101"].Status, by["MJ 101"].FinalGrade ?? 0));
        Assert.Equal(("Failed", 5.0m), (by["MJ 102"].Status, by["MJ 102"].FinalGrade ?? 0));
        var block = await Step(sp => Svc<IStudyLoadService>(sp).GetProposedBlockAsync(_student, _term2));
        Assert.Empty(block.Single(b => b.SubjectCode == "MJ 201").PrerequisiteMessages);   // MJ 101 now passed
        Assert.Contains(block, b => b.SubjectCode == "MJ 102" && b.Category == "retake");
        var failed = await Step(sp => Svc<IReportService>(sp).GetFailedStudentsAsync(_term1));
        Assert.Equal("MJ 102", failed.Single(f => f.UserId == _student).SubjectCode);
    }

    [PostgresFact]
    public async Task CorrectedRetake_CountsTowardBackToRegular()
    {
        await Seed();
        await Admit();
        await Enroll(_term1, "MJ 101", "MJ 102");
        await Grade("MJ 101", _term1, 5.0m);
        await Grade("MJ 102", _term1, 5.0m);
        await Step(sp => Svc<IGradeClearanceService>(sp).SetClearanceAsync(_student, _term1, true, _registrar));
        await Enroll(_term2, "MJ 101", "MJ 102");
        await Grade("MJ 101", _term2, 5.0m);    // failed again, before being marked irregular
        await Step(sp => Svc<IStudentRecordService>(sp).SetStandingAsync(_student, isRegular: false));

        await Correct("MJ 101", _term2, 5.0m, 2.0m);    // the correction, after, makes it a pass

        var s = await Step(sp => Svc<IStudentRecordService>(sp).GetStandingAsync(_student));
        Assert.Equal(3m, s.BackMajorUnitsPassed);
    }

    [PostgresFact]
    public async Task CollegeHeadAddingAfterEnrollment_ReachesTheAddingDroppingForm()
    {
        await Seed();
        await Admit();
        await Enroll(_term1, "MJ 101");
        // The first enrollment happened an hour before the College Head's add.
        await Step(async sp =>
        {
            var db = Svc<AppDbContext>(sp);
            var first = await db.StudyLoads.SingleAsync(l => l.UserID == _student);
            first.CreatedAt = DateTime.UtcNow.AddHours(-1);
            await db.SaveChangesAsync();
        });
        Assert.IsType<OkObjectResult>(await Step(sp => Loads(sp, _collegeHead, RoleUtils.CollegeHead)
            .EnrollBatch(new EnrollBatchRequestDto { UserId = _student, TermId = _term1, ClassIds = { _class[("MJ 102", _term1)] } })));
        Assert.IsType<OkObjectResult>(await Step(sp => Loads(sp, _registrar, RoleUtils.Registrar)
            .FinalizeBatch(new FinalizeStudyLoadsRequestDto { UserId = _student, TermId = _term1 })));

        var changes = await Step(sp => Svc<IStudyLoadChangeService>(sp).GetAsync(_student, _term1));
        Assert.Equal(("Added", "MJ 102"), (Assert.Single(changes).Kind, changes[0].SubjectCode));
    }

    [PostgresFact]
    public async Task SubjectsSavedTogether_FinalizedInParts_AreNotAdds()
    {
        await Seed();
        await Admit();
        await Step(sp => Loads(sp, _collegeHead, RoleUtils.CollegeHead)
            .EnrollBatch(new EnrollBatchRequestDto { UserId = _student, TermId = _term1, ClassIds = { _class[("MJ 101", _term1)], _class[("MJ 102", _term1)] } }));
        var one = await LoadOf("MJ 101", _term1);
        await Step(sp => Loads(sp, _registrar, RoleUtils.Registrar).FinalizeBatch(new FinalizeStudyLoadsRequestDto { UserId = _student, TermId = _term1, StudyLoadIds = new List<Guid> { one } }));
        await Step(sp => Loads(sp, _registrar, RoleUtils.Registrar).FinalizeBatch(new FinalizeStudyLoadsRequestDto { UserId = _student, TermId = _term1 }));

        Assert.Empty(await Step(sp => Svc<IStudyLoadChangeService>(sp).GetAsync(_student, _term1)));
    }

    [PostgresFact]
    public async Task AHoldOnALaterTerm_DoesNotBlockTheCurrentTerm_ButAnEarlierHoldDoes()
    {
        await Seed();
        await Admit();
        await Enroll(_term2, "MJ 202");     // next semester's load, not cleared

        Assert.True(Assert.Single(await Enroll(_term1, "MJ 101")).Enrolled);

        await Assert.ThrowsAsync<InvalidOperationException>(() => Enroll(_term2, "MJ 102"));   // term 1 is on hold
    }

    [PostgresFact]
    public async Task OverloadBlockedForcedWithdrawnRenameAndMidSemesterShift()
    {
        await Seed();
        await Admit();

        // Blocked: MJ 201 needs MJ 101.
        var blocked = await Enroll(_term2, "MJ 201");
        Assert.False(Assert.Single(blocked).Enrolled);
        Assert.Equal(0, await Step(sp => Svc<AppDbContext>(sp).StudyLoads.CountAsync(l => l.UserID == _student)));

        // Forced by the Registrar, with the audit fields saved.
        var forced = await Step(sp => Svc<IStudyLoadService>(sp).EnrollSingleAsync(new EnrollSingleRequestDto { UserId = _student, ClassId = _class[("MJ 201", _term2)], Force = true, ForceReason = "Dean approved" }, _registrar, RoleUtils.Registrar));
        Assert.True(forced.Success);
        Assert.True(await Step(sp => Svc<AppDbContext>(sp).StudyLoads.AnyAsync(l => l.UserID == _student && l.IsForced && l.ForcedReason == "Dean approved")));

        // Over the limit: refused without a reason and nothing saved; with one, approval and loads save together.
        var limit = await Step(sp => Svc<IStudyLoadService>(sp).GetUnitLimitAsync(_student, _term1));
        await Step(async sp =>
        {
            var db = Svc<AppDbContext>(sp);
            foreach (var i in Enumerable.Range(0, 8))
            {
                var s = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "X " + i, SubjectTitle = "x", LecUnits = 3, ProgramID = _program, YearLevel = 3, DefaultSemester = 1 };
                var c = new Class { ClassID = Guid.NewGuid(), SubjectID = s.SubjectID, TermID = _term1, ClassName = "X" + i, CreatedAt = DateTime.UtcNow };
                db.Subjects.Add(s); db.Classes.Add(c); _class[("X " + i, _term1)] = c.ClassID;
            }
            await db.SaveChangesAsync();
        });
        var many = Enumerable.Range(0, 8).Select(i => _class[("X " + i, _term1)]).ToList();
        var noReason = await Record.ExceptionAsync(() => Step(sp => Svc<IStudyLoadService>(sp).EnrollBatchAsync(new EnrollBatchRequestDto { UserId = _student, TermId = _term1, ClassIds = many, AsPending = true }, _collegeHead, RoleUtils.CollegeHead)));
        Assert.IsType<InvalidOperationException>(noReason);
        Assert.Equal(0, await Step(sp => Svc<AppDbContext>(sp).StudyLoads.CountAsync(l => l.UserID == _student && many.Contains(l.ClassID))));
        var withReason = await Step(sp => Svc<IStudyLoadService>(sp).EnrollBatchAsync(new EnrollBatchRequestDto { UserId = _student, TermId = _term1, ClassIds = many, AsPending = true, OverloadReason = "Catching up" }, _collegeHead, RoleUtils.CollegeHead));
        Assert.All(withReason, r => Assert.True(r.Enrolled));
        Assert.True((await Step(sp => Svc<IStudyLoadService>(sp).GetUnitLimitAsync(_student, _term1))).IsOverloaded);

        // Withdrawn prints W; re-enrolling is recorded.
        await Step(sp => Svc<IStudyLoadService>(sp).EnrollBatchAsync(new EnrollBatchRequestDto { UserId = _student, TermId = _term1, ClassIds = { _class[("MJ 101", _term1)] }, OverloadReason = "Still catching up" }, _registrar, RoleUtils.Registrar));
        var load = await LoadOf("MJ 101", _term1);
        await Step(sp => Loads(sp, _registrar, RoleUtils.Registrar).UpdateStatus(load, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Withdrawn, Reason = "Medical" }));
        Assert.Contains((await Step(sp => Svc<IStudentRecordService>(sp).GetTranscriptAsync(_student))).Terms.SelectMany(t => t.Rows), r => r.SubjectCode == "MJ 101" && r.Final == "W");
        await Step(sp => Loads(sp, _registrar, RoleUtils.Registrar).UpdateStatus(load, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Enrolled }));
        Assert.Equal("Re-enrolled", (await Step(sp => Svc<IStudyLoadChangeService>(sp).GetAsync(_student, _term1))).Last().Kind);

        // Renaming a school renames its credits.
        var school = await Step(sp => Svc<IAccreditedSchoolService>(sp).CreateAsync(new SaveAccreditedSchoolDto { Name = "Old " + _tag }));
        await Step(sp => Svc<ICreditedSubjectService>(sp).CreateAsync(new CreateCreditedSubjectDto { UserId = _student, SubjectId = _subject["GE 202"], SourceSchool = "Old " + _tag, CreditedUnits = 3 }, _registrar));
        await Step(sp => Svc<IAccreditedSchoolService>(sp).UpdateAsync(school.SchoolId, new SaveAccreditedSchoolDto { Name = "New " + _tag }));
        Assert.Equal("New " + _tag, (await Step(sp => Svc<ICreditedSubjectService>(sp).GetByStudentAsync(_student))).Single().SourceSchool);

        // Mid-semester shift: open subjects are reported, and still listed for crediting.
        var shift = await Step(sp => Svc<IStudentRecordService>(sp).ShiftProgramAsync(_student, new ShiftProgramDto { ProgramId = _otherProgram, Reason = "Changed course" }));
        Assert.Equal((2, 8), (shift.InProgressSubjects, shift.PendingSubjects));
        var previous = await Step(sp => Svc<IStudentRecordService>(sp).GetPreviousProgramSubjectsAsync(_student));
        Assert.Contains(previous, p => p.SubjectCode == "MJ 101" && p.Status == "InProgress");
    }

    /// <summary>Saves a response as the API would send it, for checking the apps' parsing against real output.</summary>
    private static async Task Dump(string name, object value)
    {
        var dir = Environment.GetEnvironmentVariable("TEST_JSON_OUT");
        if (string.IsNullOrEmpty(dir)) return;
        Directory.CreateDirectory(dir);
        await File.WriteAllTextAsync(Path.Combine(dir, name + ".json"),
            System.Text.Json.JsonSerializer.Serialize(value, new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web)));
    }

    /// <summary>Every read screen for every student and term already in the database. Read-only.</summary>
    [PostgresFact]
    public async Task EveryReadScreen_WorksOnExistingData()
    {
        var students = await Step(sp => Svc<AppDbContext>(sp).UserDetails.Where(u => u.User != null && u.User.Role == RoleUtils.Student).Select(u => u.UserID).ToListAsync());
        var terms = await Step(sp => Svc<AppDbContext>(sp).AcademicTerms.Select(t => t.TermID).ToListAsync());
        var programs = await Step(sp => Svc<AppDbContext>(sp).AcademicPrograms.Select(p => p.ProgramID).ToListAsync());
        Assert.NotEmpty(students);

        foreach (var id in students)
        {
            var hasProgram = await Step(sp => Svc<AppDbContext>(sp).UserDetails.AnyAsync(u => u.UserID == id && u.ProgramID != null));
            if (hasProgram) await Step(sp => Svc<IStudentRecordService>(sp).GetEvaluationAsync(id));
            await Step(sp => Svc<IStudentRecordService>(sp).GetTranscriptAsync(id));
            await Step(sp => Svc<IStudentRecordService>(sp).GetPersonalDetailsAsync(id));
            await Step(sp => Svc<IStudentRecordService>(sp).GetStandingAsync(id));
            await Step(sp => Svc<IStudentRecordService>(sp).GetPreviousProgramSubjectsAsync(id));
            await Step(sp => Svc<ICreditedSubjectService>(sp).GetByStudentAsync(id));
            await Step(sp => Svc<IGradeService>(sp).GetByStudentIdAsync(id, null, _registrar, RoleUtils.Registrar));
            foreach (var term in terms)
            {
                await Step(sp => Svc<IStudyLoadService>(sp).GetByStudentAsync(id, term));
                await Step(sp => Svc<IStudyLoadChangeService>(sp).GetAsync(id, term));
                if (hasProgram) await Step(sp => Svc<IStudyLoadService>(sp).GetProposedBlockAsync(id, term));
            }
        }
        foreach (var term in terms)
        {
            await Step(sp => Svc<IReportService>(sp).GetEnrollmentSummaryAsync(term));
            await Step(sp => Svc<IReportService>(sp).GetEnrollmentStatisticsAsync(term));
            await Step(sp => Svc<IReportService>(sp).GetClassListsAsync(term, null));
            await Step(sp => Svc<IReportService>(sp).GetClassSizesAsync(term));
            await Step(sp => Svc<IReportService>(sp).GetFailedStudentsAsync(term));
            await Step(sp => Svc<IReportService>(sp).GetTeacherLoadsAsync(term));
            await Step(sp => Svc<IReportService>(sp).GetStudentsMissingSexAsync(term));
            await Step(sp => Svc<IStudyLoadService>(sp).GetPendingSummaryAsync(term));
        }
        foreach (var program in programs) await Step(sp => Svc<IStudyLoadService>(sp).GetYearLevelSuggestionsAsync(program, null));
        await Step(sp => Svc<IReportService>(sp).GetTransfereesAsync());
        await Step(sp => Svc<IStudentRecordService>(sp).GetIrregularStudentsAsync());
        await Step(sp => Svc<IAccreditedSchoolService>(sp).GetUnlistedAsync());
        await Step(sp => Svc<IActivityLogService>(sp).SearchAsync(null, null, null, null, null, 1, 50));
    }

    [PostgresFact]
    public async Task OneStudent_ThroughAWholeSchoolYear()
    {
        await Seed();

        // ── Admission ─────────────────────────────────────────────────────
        var responseId = await Step(sp => Svc<IEnrollmentService>(sp).CreateResponseAsync(new CreateEnrollmentResponseDto { EmailAddress = _student + "@student.dbtc" }));
        Assert.Contains(await Step(sp => Svc<IEnrollmentService>(sp).GetUnprocessedResponsesAsync()), r => r.ResponseID == responseId);

        var lrn = "9" + Random.Shared.NextInt64(10_000_000_000, 99_999_999_999);
        var appId = await Step(sp => Svc<IEnrollmentService>(sp).CreateApplicationAsync(new CreateEnrollmentApplicationDto
        {
            ResponseID = responseId, ProgramID = _program, TermID = _term1,
            Form = new EnrollmentFormDto
            {
                FirstName = "Test", MiddleName = "Reyes", LastName = "Student" + _tag, Suffix = "", DateOfBirth = new DateOnly(2007, 5, 1),
                PlaceOfBirth = "Cebu City", Sex = "Female", CivilStatus = "Single", Nationality = "Filipino", MobileNumber = "09123456789",
                HouseStreet = "12 Rizal St", Barangay = "Punta Princesa", CityMunicipality = "Cebu City", Province = "Cebu", ZipCode = "6000",
                LastSchoolAttended = "Abellana National School", SchoolAddress = "Cebu", YearGraduated = new DateOnly(2025, 3, 1),
                PreviousCollege = "N/A", PreviousCourse = "N/A", YearLevel = 1, StudentType = 1, LRN = lrn,
                FamilyMedicalConditionsSelected = new List<string> { "None" }
            },
            Contacts = new List<ContactDto> { new() { FirstName = "Mama", LastName = "Student", RelationType = 1, ContactNo = "09123456780" } }
        }, _registrar));
        await Step(sp => Svc<IEnrollmentService>(sp).ApproveApplicationAsync(appId, _registrar));
        await Step(sp => Svc<IEnrollmentService>(sp).LinkAccountAsync(appId, _student + "@student.dbtc", _registrar));

        var details = await Step(sp => Svc<IStudentRecordService>(sp).GetPersonalDetailsAsync(_student));
        Assert.Equal(("Reyes", "Female", "12 Rizal St, Punta Princesa, Cebu City, Cebu", true), (details.MiddleName, details.Sex, details.Address, details.HasEnrollmentForm));

        // ── Enrollment: College Head builds Pending, Registrar finalizes ──
        var block = await Step(sp => Svc<IStudyLoadService>(sp).GetProposedBlockAsync(_student, _term1));
        Assert.Contains(block, b => b.SubjectCode == "MJ 101");

        var first = new[] { "MJ 101", "MJ 102", "GE 101", "NSTP 1" }.Select(c => _class[(c, _term1)]).ToList();
        var saved = Assert.IsType<OkObjectResult>(await Step(sp => Loads(sp, _collegeHead, RoleUtils.CollegeHead)
            .EnrollBatch(new EnrollBatchRequestDto { UserId = _student, TermId = _term1, ClassIds = first })));
        Assert.All((List<EnrollBatchResponseDto>)saved.Value!, r => Assert.True(r.Enrolled));
        Assert.Contains(await Step(sp => Svc<IStudyLoadService>(sp).GetPendingSummaryAsync(_term1)), p => p.UserId == _student);

        await Step(sp => Svc<IStudyLoadService>(sp).FinalizeBatchAsync(new FinalizeStudyLoadsRequestDto { UserId = _student, TermId = _term1 }, _registrar, RoleUtils.Registrar));
        var loads = await Step(sp => Svc<IStudyLoadService>(sp).GetByStudentAsync(_student, _term1));
        Assert.Equal(4, loads.Count(l => l.LoadStatus == "Enrolled"));
        Assert.True((await Step(sp => Svc<IStudyLoadService>(sp).GetUnitLimitAsync(_student, _term1))).CurrentUnits >= 12);

        // ── Changes after enrollment ──────────────────────────────────────
        var refused = await Step(sp => Loads(sp, _registrar, RoleUtils.Registrar).EnrollSingle(new EnrollSingleRequestDto { UserId = _student, ClassId = _class[("MJ 103", _term1)] }));
        Assert.IsType<BadRequestObjectResult>(refused);
        Assert.IsType<OkObjectResult>(await Step(sp => Loads(sp, _registrar, RoleUtils.Registrar)
            .EnrollSingle(new EnrollSingleRequestDto { UserId = _student, ClassId = _class[("MJ 103", _term1)], ChangeReason = "Late add" })));
        var mj103 = await LoadOf("MJ 103", _term1);
        Assert.IsType<BadRequestObjectResult>(await Step(sp => Loads(sp, _registrar, RoleUtils.Registrar).UpdateStatus(mj103, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Dropped })));
        Assert.IsType<OkObjectResult>(await Step(sp => Loads(sp, _registrar, RoleUtils.Registrar).UpdateStatus(mj103, new UpdateStudyLoadStatusDto { LoadStatus = StudyLoadStatus.Dropped, Reason = "Schedule conflict" })));
        var changes = await Step(sp => Svc<IStudyLoadChangeService>(sp).GetAsync(_student, _term1));
        Assert.Equal(new[] { "Added", "Dropped" }, changes.Select(c => c.Kind));
        Assert.All(changes, c => Assert.Equal("Rita Staff", c.ChangedBy));

        // ── Reports while enrolled ────────────────────────────────────────
        var classList = Assert.Single(await Step(sp => Svc<IReportService>(sp).GetClassListsAsync(_term1, _class[("MJ 101", _term1)])));
        Assert.Equal(("F", "Ben Staff"), (classList.Students.Single().Sex, classList.TeacherName));
        Assert.Equal(5, (await Step(sp => Svc<IReportService>(sp).GetClassListsAsync(_term1, null))).Count);
        var stats = await Step(sp => Svc<IReportService>(sp).GetEnrollmentStatisticsAsync(_term1));
        Assert.Equal(1, stats.Single(r => r.ProgramCode == "T" + _tag).Female[0]);
        Assert.Empty(await Step(sp => Svc<IReportService>(sp).GetStudentsMissingSexAsync(_term1)));
        await Step(sp => Svc<IReportService>(sp).GetEnrollmentSummaryAsync(_term1));
        await Step(sp => Svc<IReportService>(sp).GetClassSizesAsync(_term1));
        await Step(sp => Svc<IReportService>(sp).GetTeacherLoadsAsync(_term1));

        // ── Grades: two majors failed, the rest passed ────────────────────
        await Grade("MJ 101", _term1, 5.0m);
        await Grade("MJ 102", _term1, 5.0m);
        await Grade("GE 101", _term1, 2.5m);
        await Grade("NSTP 1", _term1, 1.5m);
        Assert.Equal(2, (await Step(sp => Svc<IReportService>(sp).GetFailedStudentsAsync(_term1))).Count);

        // Grades stay hidden from the student until released.
        await Step(sp => Svc<IGradeClearanceService>(sp).SetClearanceAsync(_student, _term1, false, _registrar));
        var hidden = await Step(async sp =>
        {
            try { return (await Svc<IGradeService>(sp).GetByStudentIdAsync(_student, _term1, _student, RoleUtils.Student)).Count; }
            catch (UnauthorizedAccessException) { return 0; }
        });
        Assert.Equal(0, hidden);
        await Step(sp => Svc<IGradeClearanceService>(sp).SetClearanceAsync(_student, _term1, true, _registrar));
        Assert.Equal(4, (await Step(sp => Svc<IGradeService>(sp).GetByStudentIdAsync(_student, _term1, _student, RoleUtils.Student))).Count);

        // Grade correction: 2.5 becomes 2.0.
        var ge = (await Step(sp => Svc<IGradeService>(sp).GetByStudentIdAsync(_student, _term1, _registrar, RoleUtils.Registrar))).Single(g => g.SubjectCode == "GE 101");
        var correction = await Step(sp => Svc<IGradeCorrectionService>(sp).RequestCorrectionAsync(new CreateGradeCorrectionDto { GradeId = ge.GradeId, CorrectionPeriod = 2, OldGrade = 2.5m, NewGrade = 2.0m, Reason = "Encoding error" }, _teacher));
        Assert.Contains(await Step(sp => Svc<IGradeCorrectionService>(sp).GetPendingAsync()), c => c.CorrectionId == correction.CorrectionId);
        await Step(sp => Svc<IGradeCorrectionService>(sp).ApproveCorrectionAsync(correction.CorrectionId, _registrar));
        Assert.Equal(2.0m, (await Step(sp => Svc<IGradeService>(sp).GetByStudentIdAsync(_student, _term1, _registrar, RoleUtils.Registrar))).Single(g => g.SubjectCode == "GE 101").FinalGrade);

        // ── Next semester: a hold blocks enrollment ───────────────────────
        await Step(sp => Svc<IGradeClearanceService>(sp).SetClearanceAsync(_student, _term1, false, _registrar));
        await Assert.ThrowsAsync<InvalidOperationException>(() => Step(sp => Svc<IStudyLoadService>(sp)
            .EnrollBatchAsync(new EnrollBatchRequestDto { UserId = _student, TermId = _term2, ClassIds = { _class[("MJ 202", _term2)] } }, _registrar, RoleUtils.Registrar)));
        await Step(sp => Svc<IGradeClearanceService>(sp).SetClearanceAsync(_student, _term1, true, _registrar));

        var next = await Step(sp => Svc<IStudyLoadService>(sp).GetProposedBlockAsync(_student, _term2));
        Assert.Contains(next, b => b.SubjectCode == "MJ 101" && b.Category == "retake");
        Assert.Contains(next, b => b.SubjectCode == "MJ 201" && b.PrerequisiteMessages.Count > 0);   // MJ 101 not passed yet

        // ── Credits ───────────────────────────────────────────────────────
        await Step(sp => Svc<IAccreditedSchoolService>(sp).CreateAsync(new SaveAccreditedSchoolDto { Name = "Test College " + _tag }));
        var transfer = await Step(sp => Svc<ICreditedSubjectService>(sp).CreateAsync(new CreateCreditedSubjectDto { UserId = _student, SubjectId = _subject["MJ 204"], SourceSchool = "test  college " + _tag, Grade = "1.5", SchoolYear = "2024-2025", CreditedUnits = 3 }, _registrar));
        Assert.Equal("Test College " + _tag, transfer.SourceSchool);
        var partial = await Step(sp => Svc<ICreditedSubjectService>(sp).CreateAsync(new CreateCreditedSubjectDto { UserId = _student, SubjectId = _subject["GE 202"], SourceSchool = "Other School " + _tag, CreditedUnits = 2 }, _registrar));
        Assert.True(partial.IsPartial);
        await Step(sp => Svc<ICreditedSubjectService>(sp).CreateAsync(new CreateCreditedSubjectDto { UserId = _student, SubjectId = _subject["GE 203"], SourceSchool = "Test College " + _tag, Grade = "1.25", CreditedUnits = 3, Kind = CreditKinds.CrossEnrollment, TermId = _term2 }, _registrar));
        Assert.Contains(await Step(sp => Svc<IAccreditedSchoolService>(sp).GetUnlistedAsync()), u => u.Name == "Other School " + _tag);
        Assert.Contains(await Step(sp => Svc<IReportService>(sp).GetTransfereesAsync()), t => t.UserId == _student && t.CreditedSubjects == 2);

        var eval = await Step(sp => Svc<IStudentRecordService>(sp).GetEvaluationAsync(_student));
        var by = eval.Subjects.ToDictionary(x => x.SubjectCode);
        Assert.Equal("Failed", by["MJ 101"].Status);
        Assert.Equal("Dropped", by["MJ 103"].Status);
        Assert.Equal("Credited", by["MJ 204"].Status);
        Assert.Equal("PartiallyCredited", by["GE 202"].Status);
        Assert.Equal("CrossEnrolled", by["GE 203"].Status);
        Assert.Equal("MJ 101", by["MJ 201"].Prerequisites);

        // ── Regular and irregular ─────────────────────────────────────────
        var standing = await Step(sp => Svc<IStudentRecordService>(sp).GetStandingAsync(_student));
        Assert.Equal("MarkIrregular", standing.Suggestion);
        Assert.Equal(new[] { "MJ 101", "MJ 102", "MJ 103" }, standing.UnresolvedSubjects);
        await Step(sp => Svc<IStudentRecordService>(sp).SetStandingAsync(_student, isRegular: false));

        // ── Second semester: retakes pass ─────────────────────────────────
        var retakes = new[] { "MJ 101", "MJ 102" }.Select(c => _class[(c, _term2)]).ToList();
        var enrolled = await Step(sp => Svc<IStudyLoadService>(sp).EnrollBatchAsync(new EnrollBatchRequestDto { UserId = _student, TermId = _term2, ClassIds = retakes }, _registrar, RoleUtils.Registrar));
        Assert.All(enrolled, r => Assert.True(r.Enrolled, string.Join("; ", r.Reasons)));

        await Grade("MJ 101", _term2, 2.0m);
        Assert.Equal(3m, (await Step(sp => Svc<IStudentRecordService>(sp).GetStandingAsync(_student))).BackMajorUnitsPassed);
        await Grade("MJ 102", _term2, 2.25m);
        var ready = await Step(sp => Svc<IStudentRecordService>(sp).GetStandingAsync(_student));
        Assert.Equal((6m, "MarkRegular"), (ready.BackMajorUnitsPassed, ready.Suggestion));
        Assert.Contains(await Step(sp => Svc<IStudentRecordService>(sp).GetIrregularStudentsAsync()), s => s.UserId == _student && s.ReadyToBeRegular);
        await Step(sp => Svc<IStudentRecordService>(sp).SetStandingAsync(_student, isRegular: true));

        // ── End of year ───────────────────────────────────────────────────
        var promo = await Step(sp => Svc<IStudyLoadService>(sp).GetYearLevelSuggestionsAsync(_program, 1));
        Assert.Contains(promo, s => s.UserId == _student);
        await Step(sp => Svc<IStudyLoadService>(sp).GetYearLevelSuggestionAsync(_student));
        await Step(sp => Svc<IStudyLoadService>(sp).ApplyYearLevelsAsync(new List<YearLevelChangeDto> { new() { UserId = _student, YearLevel = 2 } }));

        await Step(sp => Svc<IStudentRecordService>(sp).UpdatePersonalDetailsAsync(_student, new UpdatePersonalDetailsDto { DateAdmitted = "1st Semester, 2024-2025", Sex = "Female" }, _registrar));
        var tor = await Step(sp => Svc<IStudentRecordService>(sp).GetTranscriptAsync(_student));
        Assert.Equal($"STUDENT{_tag.ToUpperInvariant()}, Test Reyes", tor.FullName);
        Assert.Equal(("1st Semester, 2024-2025", "Abellana National School"), (tor.DateAdmitted, tor.EntranceData));
        Assert.Equal(2, tor.Terms.Count);
        var firstTerm = tor.Terms[0].Rows.ToDictionary(r => r.SubjectCode);
        Assert.Equal(("5.00", "DO", "2.00"), (firstTerm["MJ 101"].Final, firstTerm["MJ 103"].Final, firstTerm["GE 101"].Final));
        var secondTerm = tor.Terms[1].Rows.ToDictionary(r => r.SubjectCode);
        Assert.Equal("2.00", secondTerm["MJ 101"].Final);
        Assert.Contains("cross-enrolled at Test College", secondTerm["GE 203"].SubjectTitle);
        Assert.Equal(2, tor.Credits.Count);

        await Dump("transcript", tor);
        await Dump("evaluation", await Step(sp => Svc<IStudentRecordService>(sp).GetEvaluationAsync(_student)));
        await Dump("personal_details", await Step(sp => Svc<IStudentRecordService>(sp).GetPersonalDetailsAsync(_student)));
        await Dump("credits", await Step(sp => Svc<ICreditedSubjectService>(sp).GetByStudentAsync(_student)));
        await Dump("changes", await Step(sp => Svc<IStudyLoadChangeService>(sp).GetAsync(_student, _term1)));
        await Dump("grades", await Step(sp => Svc<IGradeService>(sp).GetByStudentIdAsync(_student, null, _registrar, RoleUtils.Registrar)));
        await Dump("statistics", await Step(sp => Svc<IReportService>(sp).GetEnrollmentStatisticsAsync(_term1)));
        await Dump("class_lists", await Step(sp => Svc<IReportService>(sp).GetClassListsAsync(_term1, null)));
        await Dump("transferees", await Step(sp => Svc<IReportService>(sp).GetTransfereesAsync()));
        await Dump("schools", await Step(sp => Svc<IAccreditedSchoolService>(sp).GetAllAsync()));
        await Dump("unlisted", await Step(sp => Svc<IAccreditedSchoolService>(sp).GetUnlistedAsync()));
        await Step(sp => Svc<IStudentRecordService>(sp).SetStandingAsync(_student, isRegular: false));
        await Dump("standing", await Step(sp => Svc<IStudentRecordService>(sp).GetStandingAsync(_student)));
        await Dump("irregular", await Step(sp => Svc<IStudentRecordService>(sp).GetIrregularStudentsAsync()));
        await Step(sp => Svc<IStudentRecordService>(sp).SetStandingAsync(_student, isRegular: true));

        // ── Shifting ──────────────────────────────────────────────────────
        var shift = await Step(sp => Svc<IStudentRecordService>(sp).ShiftProgramAsync(_student, new ShiftProgramDto { ProgramId = _otherProgram, Reason = "Changed course" }));
        Assert.Equal("U" + _tag, shift.ProgramCode);
        var previous = await Step(sp => Svc<IStudentRecordService>(sp).GetPreviousProgramSubjectsAsync(_student));
        await Dump("shift", shift);
        await Dump("previous_subjects", previous);
        var match = previous.Single(p => p.SubjectCode == "GE 101");
        Assert.Equal((_subject["other GE 101"], 2.0m), (match.SuggestedSubjectId ?? default, match.FinalGrade ?? 0));
        await Step(sp => Svc<ICreditedSubjectService>(sp).CreateAsync(new CreateCreditedSubjectDto { UserId = _student, SubjectId = _subject["other GE 101"], SourceSchool = "Don Bosco Technical College - Cebu", Grade = "2.00", CreditedUnits = 3 }, _registrar));
        Assert.Equal("Credited", Assert.Single((await Step(sp => Svc<IStudentRecordService>(sp).GetEvaluationAsync(_student))).Subjects).Status);
        Assert.Contains((await Step(sp => Svc<IStudentRecordService>(sp).GetTranscriptAsync(_student))).Terms.SelectMany(t => t.Rows), r => r.SubjectCode == "MJ 101");

        // ── The log has the student's history ─────────────────────────────
        var log = await Step(sp => Svc<IActivityLogService>(sp).SearchAsync(null, null, null, _student, null, 1, 50));
        Assert.Contains(log.Items, i => i.Action == ActivityActions.LoadStatusChanged && i.Summary.Contains("Schedule conflict"));
    }
}
