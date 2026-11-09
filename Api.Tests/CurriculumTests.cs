using System.Text;
using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Class;
using Api.DTOs.Curriculum;
using Api.DTOs.Setup;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

// A program can have several curricula. A student keeps the curriculum of their batch until they graduate;
// students who start in or after a new curriculum's school year get it automatically.
public class CurriculumTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly CurriculumService _curricula;
    private readonly Guid _oldId = Guid.NewGuid();
    private readonly Guid _newId = Guid.NewGuid();
    private readonly Guid _termId = Guid.NewGuid();
    private readonly Guid _oldStudent = Guid.NewGuid();
    private readonly Guid _newStudent = Guid.NewGuid();

    public CurriculumTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _curricula = new CurriculumService(_context);

        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 1, ProgramCode = "BTVTED-MT", ProgramName = "BTVTEd Mechanical" },
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.Curricula.AddRange(
            new Curriculum { CurriculumID = _oldId, ProgramID = 1, Name = "2021 curriculum", EffectiveFromYear = 2021 },
            new Curriculum { CurriculumID = _newId, ProgramID = 1, Name = "2026 curriculum", EffectiveFromYear = 2026 });
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _termId, SchoolYear = "2026-2027", Semester = 1, IsActive = true });

        // Old curriculum: three 1st-year and four 2nd-year subjects. New curriculum: two 1st-year, one 2nd-year.
        AddSubject("MT 101", 1, _oldId);
        AddSubject("MT 102", 1, _oldId);
        AddSubject("GEC 101", 1, _oldId);
        AddSubject("MT 201", 2, _oldId);
        AddSubject("MT 202", 2, _oldId);
        AddSubject("MT 203", 2, _oldId);
        AddSubject("MT 204", 2, _oldId);
        AddSubject("MT 101A", 1, _newId);
        AddSubject("GEC 101", 1, _newId);   // the same code may exist in both curricula
        AddSubject("MT 201A", 2, _newId);

        AddStudent(_oldStudent, "Kurt", 2, _oldId);
        AddStudent(_newStudent, "Ana", 1, _newId);
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private Subject AddSubject(string code, int year, Guid curriculumId, int programId = 1, int semester = 1)
    {
        var s = new Subject
        {
            SubjectID = Guid.NewGuid(), SubjectCode = code, SubjectTitle = code, LecUnits = 3,
            ProgramID = programId, CurriculumID = curriculumId, YearLevel = year, DefaultSemester = semester
        };
        _context.Subjects.Add(s);
        return s;
    }

    private void AddStudent(Guid id, string name, int year, Guid? curriculumId, int programId = 1)
    {
        _context.Users.Add(new User { UserID = id, FirebaseUID = "fb-" + id, Email = $"{id}@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(), UserID = id, Firstname = name, Lastname = "Test",
            ProgramID = programId, YearLevel = year, CurriculumID = curriculumId
        });
    }

    private StudyLoadService StudyLoads() => new(_context, new StudyLoadRepository(_context),
        new Mock<IGradeClearanceService>().Object, NullLogger<StudyLoadService>.Instance);

    // ── Which curriculum a batch gets ──────────────────────────────────

    [Theory]
    [InlineData("2026-2027", 2026)]
    [InlineData(" 2025 - 2026 ", 2025)]
    [InlineData("SY", null)]
    [InlineData(null, null)]
    public void StartYear_ReadsTheFirstYear(string? schoolYear, int? expected)
    {
        Assert.Equal(expected, CurriculumService.StartYear(schoolYear));
    }

    [Theory]
    [InlineData(2026, 1, 2026)]
    [InlineData(2026, 2, 2025)]
    [InlineData(2026, 4, 2023)]
    [InlineData(2026, null, 2026)]
    public void BatchYear_IsTheSchoolYearTheStudentStarted(int termYear, int? yearLevel, int expected)
    {
        Assert.Equal(expected, CurriculumService.BatchYear(termYear, yearLevel));
    }

    [Theory]
    [InlineData(2026, "2026 curriculum")]   // freshmen of the new curriculum's first year
    [InlineData(2030, "2026 curriculum")]
    [InlineData(2025, "2021 curriculum")]   // last year's freshmen keep the old one
    [InlineData(2010, "2021 curriculum")]   // older than every curriculum: the oldest one
    public void ForBatch_PicksTheNewestCurriculumInEffect(int batchYear, string expected)
    {
        var picked = CurriculumService.ForBatch(_context.Curricula.Where(c => c.ProgramID == 1).ToList(), batchYear);
        Assert.Equal(expected, picked!.Name);
    }

    [Fact]
    public async Task ForBatchAsync_ProgramWithoutCurricula_ReturnsNull()
    {
        Assert.Null(await _curricula.ForBatchAsync(2, 2026));
    }

    // ── The student's own subjects ─────────────────────────────────────

    [Fact]
    public async Task UnitLimit_UsesTheStudentsCurriculum()
    {
        // Old curriculum, 2nd year 1st sem: four 3-unit subjects. New curriculum: one.
        var old = await StudyLoads().GetUnitLimitAsync(_oldStudent, _termId);
        Assert.Equal(12m, old.CurriculumUnits);

        AddStudent(Guid.NewGuid(), "Bea", 2, _newId);
        var beaId = _context.UserDetails.Local.First(u => u.Firstname == "Bea").UserID;
        await _context.SaveChangesAsync();
        var bea = await StudyLoads().GetUnitLimitAsync(beaId, _termId);
        Assert.Equal(3m, bea.CurriculumUnits);
    }

    [Fact]
    public async Task UnitLimit_StudentWithoutCurriculum_UsesTheWholeProgram()
    {
        var id = Guid.NewGuid();
        AddStudent(id, "Old", 2, null);
        await _context.SaveChangesAsync();
        var limit = await StudyLoads().GetUnitLimitAsync(id, _termId);
        Assert.Equal(15m, limit.CurriculumUnits);   // MT 201-204 + MT 201A
    }

    [Fact]
    public async Task ProposedBlock_OnlyOffersTheStudentsCurriculum()
    {
        var items = await StudyLoads().GetProposedBlockAsync(_newStudent, _termId);
        var codes = items.Select(i => i.SubjectCode).ToList();
        Assert.Contains("MT 101A", codes);
        Assert.DoesNotContain("MT 101", codes);
        Assert.DoesNotContain("MT 102", codes);
    }

    // ── Opening classes for a term ─────────────────────────────────────

    [Fact]
    public async Task OpenTerm_EachYearLevelUsesItsBatchsCurriculum()
    {
        var classes = new ClassService(_context, new ClassRepository(_context), new ClassScheduleRepository(_context));
        var result = await classes.OpenTermAsync(new OpenTermRequestDto { ProgramId = 1, TermId = _termId, Sections = 1 },
            dryRun: true, Guid.NewGuid());

        // 2026-2027: 1st years (batch 2026) on the new curriculum (2 subjects),
        // 2nd years (batch 2025) still on the old one (4 subjects).
        Assert.Equal(2, result.PerYear[1]);
        Assert.Equal(4, result.PerYear[2]);
    }

    [Fact]
    public async Task ClassList_NamesTheCurriculum_OnlyWhenTheProgramHasSeveral()
    {
        var mt = _context.Subjects.Local.First(s => s.SubjectCode == "MT 101A");
        var bsitCurriculum = Guid.NewGuid();
        _context.Curricula.Add(new Curriculum { CurriculumID = bsitCurriculum, ProgramID = 2, Name = "BSIT only", EffectiveFromYear = 2023 });
        var it = AddSubject("IT 101", 1, bsitCurriculum, programId: 2);
        _context.Classes.AddRange(
            new Class { ClassID = Guid.NewGuid(), SubjectID = mt.SubjectID, TermID = _termId, ClassName = "BTVTED-MT 1A" },
            new Class { ClassID = Guid.NewGuid(), SubjectID = it.SubjectID, TermID = _termId, ClassName = "BSIT 1A" });
        await _context.SaveChangesAsync();

        var classes = await new ClassService(_context, new ClassRepository(_context), new ClassScheduleRepository(_context))
            .GetAllAsync(termId: _termId);

        var mtClass = classes.Single(c => c.ClassName == "BTVTED-MT 1A");
        Assert.Equal("2026 curriculum", mtClass.CurriculumName);
        Assert.True(mtClass.ShowCurriculum);
        var itClass = classes.Single(c => c.ClassName == "BSIT 1A");
        Assert.Equal("BSIT only", itClass.CurriculumName);
        Assert.False(itClass.ShowCurriculum);
    }

    // ── Subjects in curricula ──────────────────────────────────────────

    private SubjectService Subjects() => new(_context, new SubjectRepository(_context),
        new SubjectPrerequisiteRepository(_context), new AcademicProgramRepository(_context));

    private static CreateSubjectDto NewSubject(string code, Guid? curriculumId) => new()
    {
        SubjectCode = code, SubjectTitle = code, LecUnits = 3, ProgramID = 1, YearLevel = 1, DefaultSemester = 1,
        CurriculumID = curriculumId
    };

    [Fact]
    public async Task CreateSubject_WithoutCurriculum_GoesToTheNewest()
    {
        var dto = await Subjects().CreateAsync(NewSubject("MT 105A", null));
        Assert.Equal(_newId, dto.CurriculumID);
        Assert.Equal("2026 curriculum", dto.CurriculumName);
    }

    [Fact]
    public async Task CreateSubject_SameCodeInAnotherCurriculum_IsAllowed_SameCurriculum_IsNot()
    {
        await Subjects().CreateAsync(NewSubject("MT 101A", _oldId));   // exists only in the new one
        await Assert.ThrowsAsync<DuplicateSubjectCodeException>(() => Subjects().CreateAsync(NewSubject("MT 101A", _newId)));
    }

    [Fact]
    public async Task CreateSubject_CurriculumOfAnotherProgram_IsRejected()
    {
        var bsit = Guid.NewGuid();
        _context.Curricula.Add(new Curriculum { CurriculumID = bsit, ProgramID = 2, Name = "BSIT", EffectiveFromYear = 2023 });
        await _context.SaveChangesAsync();
        await Assert.ThrowsAsync<ArgumentException>(() => Subjects().CreateAsync(NewSubject("X 1", bsit)));
    }

    [Fact]
    public async Task GetSubjects_FiltersByCurriculum()
    {
        var list = await Subjects().GetAllAsync(programId: 1, curriculumId: _newId);
        Assert.Equal(3, list.Count);
        Assert.All(list, s => Assert.Equal("2026 curriculum", s.CurriculumName));
    }

    [Fact]
    public async Task Prerequisite_AcrossCurricula_IsRejected()
    {
        var oldSubject = _context.Subjects.Local.First(s => s.SubjectCode == "MT 101");
        var newSubject = _context.Subjects.Local.First(s => s.SubjectCode == "MT 201A");
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => Subjects().AddPrerequisiteAsync(new CreatePrerequisiteDto
        {
            SubjectID = newSubject.SubjectID, PrerequisiteSubjectID = oldSubject.SubjectID, RequisiteType = 0
        }));
        Assert.Contains("different curricula", ex.Message);
    }

    // ── Curriculum import ──────────────────────────────────────────────

    private static MemoryStream Csv(string body) => new(Encoding.UTF8.GetBytes(
        "program,code,title,units,lec_units,lab_units,lec_hours,lab_hours,year,semester,prerequisites,corequisites,standing_year\n" + body));

    [Fact]
    public async Task Import_IntoTheChosenCurriculum()
    {
        using var csv = Csv("BTVTED-MT,MT 101,Shop Safety,3,3,0,3,0,1,1,,,\nBTVTED-MT,MT 999,New One,3,3,0,3,0,1,1,MT 101,,\n");
        var result = await new CurriculumImportService(_context)
            .ImportAsync(csv, "old.csv", csv.Length, dryRun: false, updateExisting: false, Guid.NewGuid(), _oldId);

        Assert.Equal(0, result.TotalErrors);
        Assert.Equal(1, result.Subjects.Create);   // MT 101 already exists in the old curriculum
        Assert.True(await _context.Subjects.AnyAsync(s => s.SubjectCode == "MT 999" && s.CurriculumID == _oldId));
    }

    [Fact]
    public async Task Import_WithoutCurriculum_UsesTheNewest()
    {
        using var csv = Csv("BTVTED-MT,MT 101,Shop Safety,3,3,0,3,0,1,1,,,\n");
        var result = await new CurriculumImportService(_context)
            .ImportAsync(csv, "new.csv", csv.Length, dryRun: false, updateExisting: false, Guid.NewGuid());

        Assert.Equal(1, result.Subjects.Create);   // MT 101 is only in the old curriculum
        Assert.True(await _context.Subjects.AnyAsync(s => s.SubjectCode == "MT 101" && s.CurriculumID == _newId));
    }

    [Fact]
    public async Task Import_CurriculumOfAnotherProgram_IsAnError()
    {
        using var csv = Csv("BSIT,IT 101,Intro,3,3,0,3,0,1,1,,,\n");
        var result = await new CurriculumImportService(_context)
            .ImportAsync(csv, "x.csv", csv.Length, dryRun: true, updateExisting: false, Guid.NewGuid(), _oldId);
        Assert.Contains(result.Errors, e => e.Message.Contains("not a BSIT curriculum"));
    }

    // ── Managing curricula ─────────────────────────────────────────────

    [Fact]
    public async Task GetAll_CountsAndMarksTheNewest()
    {
        var list = await _curricula.GetAllAsync(1);
        Assert.Equal(new[] { "2026 curriculum", "2021 curriculum" }, list.Select(c => c.Name));
        Assert.True(list[0].IsNewest);
        Assert.False(list[1].IsNewest);
        Assert.Equal(7, list[1].SubjectCount);
        Assert.Equal(1, list[1].StudentCount);
        Assert.Equal("2026-2027", list[0].EffectiveSchoolYear);
    }

    [Fact]
    public async Task Create_SameEffectiveYear_IsRejected()
    {
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _curricula.CreateAsync(new SaveCurriculumDto { ProgramID = 1, Name = "Again", EffectiveFromYear = 2026 }));
        Assert.Contains("already has a curriculum for SY 2026-2027", ex.Message);
    }

    [Fact]
    public async Task Create_And_Update()
    {
        var c = await _curricula.CreateAsync(new SaveCurriculumDto { ProgramID = 1, Name = " 2030 curriculum ", EffectiveFromYear = 2030 });
        Assert.Equal("2030 curriculum", c.Name);
        Assert.True(c.IsNewest);

        var edited = await _curricula.UpdateAsync(c.CurriculumID, new SaveCurriculumDto { Name = "CMO 2031", EffectiveFromYear = 2031 });
        Assert.Equal("CMO 2031", edited.Name);
        Assert.Equal(2031, edited.EffectiveFromYear);
    }

    [Fact]
    public async Task Delete_WithSubjectsOrStudents_IsBlocked_EmptyOne_IsDeleted()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() => _curricula.DeleteAsync(_oldId));

        var empty = await _curricula.CreateAsync(new SaveCurriculumDto { ProgramID = 1, Name = "Draft", EffectiveFromYear = 2032 });
        await _curricula.DeleteAsync(empty.CurriculumID);
        Assert.False(await _context.Curricula.AnyAsync(c => c.CurriculumID == empty.CurriculumID));
    }

    [Fact]
    public async Task SetStudentCurriculum_MovesTheStudent()
    {
        var (oldName, newName) = await _curricula.SetStudentCurriculumAsync(_oldStudent, _newId);
        Assert.Equal("2021 curriculum", oldName);
        Assert.Equal("2026 curriculum", newName);
        Assert.Equal(_newId, (await _context.UserDetails.FirstAsync(u => u.UserID == _oldStudent)).CurriculumID);
    }

    [Fact]
    public async Task GetStudentCurriculum_ShowsNameAndSchoolYear()
    {
        var c = await _curricula.GetStudentCurriculumAsync(_oldStudent);
        Assert.Equal(_oldId, c.CurriculumID);
        Assert.Equal("2021 curriculum", c.Name);
        Assert.Equal("2021-2022", c.EffectiveSchoolYear);
        Assert.Equal(1, c.ProgramID);
    }

    [Fact]
    public async Task SetStudentCurriculum_OtherProgramsCurriculum_IsRejected()
    {
        var bsit = Guid.NewGuid();
        _context.Curricula.Add(new Curriculum { CurriculumID = bsit, ProgramID = 2, Name = "BSIT", EffectiveFromYear = 2023 });
        await _context.SaveChangesAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(() => _curricula.SetStudentCurriculumAsync(_oldStudent, bsit));
    }

    [Fact]
    public async Task NewestOrCreate_FirstCurriculum_TakesTheProgramsSubjectsAndStudents()
    {
        // BSIT has subjects and a student from before curricula existed.
        AddSubject("IT 101", 1, Guid.Empty, programId: 2);
        var student = Guid.NewGuid();
        AddStudent(student, "Lee", 1, null, programId: 2);
        await _context.SaveChangesAsync();

        var id = await _curricula.NewestOrCreateAsync(2);

        Assert.Equal(id, (await _context.Subjects.FirstAsync(s => s.SubjectCode == "IT 101")).CurriculumID);
        Assert.Equal(id, (await _context.UserDetails.FirstAsync(u => u.UserID == student)).CurriculumID);
        Assert.Equal(id, await _curricula.NewestOrCreateAsync(2));   // no second one is made
    }
}
