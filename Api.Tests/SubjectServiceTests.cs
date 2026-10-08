using Api.Constants;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.Setup;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Tests for SubjectService.AddPrerequisiteAsync rules (task 3)
/// and the corequisite-does-not-block-enrollment invariant (task 6).
/// </summary>
public class SubjectServiceTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly SubjectService _service;

    // Concrete repositories used by SubjectService
    private readonly SubjectRepository _subjectRepo;
    private readonly SubjectPrerequisiteRepository _prereqRepo;
    private readonly AcademicProgramRepository _programRepo;

    // For the enrollment invariant test we also need StudyLoadService
    private readonly StudyLoadRepository _studyLoadRepo;
    private readonly GradeClearanceRepository _clearanceRepo;
    private readonly GradeClearanceService _clearanceService;
    private readonly StudyLoadService _studyLoadService;

    public SubjectServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);

        _subjectRepo = new SubjectRepository(_context);
        _prereqRepo = new SubjectPrerequisiteRepository(_context);
        _programRepo = new AcademicProgramRepository(_context);

        _service = new SubjectService(_context, _subjectRepo, _prereqRepo, _programRepo);

        _studyLoadRepo = new StudyLoadRepository(_context);
        _clearanceRepo = new GradeClearanceRepository(_context);
        _clearanceService = new GradeClearanceService(_context, _clearanceRepo);
        _studyLoadService = new StudyLoadService(
            _context, _studyLoadRepo, _clearanceService,
            NullLogger<StudyLoadService>.Instance);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    // ── Fixture helpers ───────────────────────────────────────────────────────

    private bool _programSeeded;

    private async Task EnsureProgramAsync()
    {
        if (_programSeeded) return;
        _context.AcademicPrograms.Add(new AcademicProgram
        {
            ProgramID = 1,
            ProgramCode = "TEST",
            ProgramName = "Test Program"
        });
        await _context.SaveChangesAsync();
        _programSeeded = true;
    }

    private async Task<Subject> MakeSubjectAsync(string code)
    {
        await EnsureProgramAsync();
        var s = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = code,
            SubjectTitle = code,
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3,
            LabUnits = 0,
            LecHours = 3,
            LabHours = 0
        };
        _context.Subjects.Add(s);
        await _context.SaveChangesAsync();
        return s;
    }

    private CreatePrerequisiteDto Dto(Guid subjectId, Guid prereqId, int type = RequisiteTypeConstants.Prerequisite) =>
        new() { SubjectID = subjectId, PrerequisiteSubjectID = prereqId, RequisiteType = type };

    // ── 1. Self-link is rejected for both types ───────────────────────────────

    [Fact]
    public async Task AddPrerequisite_SelfLink_Prerequisite_Throws()
    {
        var s = await MakeSubjectAsync("CS101");
        var dto = Dto(s.SubjectID, s.SubjectID, RequisiteTypeConstants.Prerequisite);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.AddPrerequisiteAsync(dto));
        Assert.Contains("itself", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task AddPrerequisite_SelfLink_Corequisite_Throws()
    {
        var s = await MakeSubjectAsync("CS101");
        var dto = Dto(s.SubjectID, s.SubjectID, RequisiteTypeConstants.Corequisite);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.AddPrerequisiteAsync(dto));
        Assert.Contains("itself", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    // ── 2. Exact-duplicate: same pair + same type ─────────────────────────────

    [Fact]
    public async Task AddPrerequisite_ExactDuplicate_Prerequisite_Throws()
    {
        var a = await MakeSubjectAsync("A");
        var b = await MakeSubjectAsync("B");

        await _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Prerequisite));

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Prerequisite)));
        Assert.Contains("prerequisite", ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("already exists", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task AddPrerequisite_ExactDuplicate_Corequisite_Throws()
    {
        var a = await MakeSubjectAsync("A");
        var b = await MakeSubjectAsync("B");

        await _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Corequisite));

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Corequisite)));
        Assert.Contains("corequisite", ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("already exists", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    // ── 3. Pair-conflict: same pair but opposite type ─────────────────────────

    [Fact]
    public async Task AddPrerequisite_PairExistsAsPrerequisite_AddingCorequisite_Throws()
    {
        var a = await MakeSubjectAsync("A");
        var b = await MakeSubjectAsync("B");

        await _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Prerequisite));

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Corequisite)));
        Assert.Contains("corequisite", ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("prerequisite", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task AddPrerequisite_PairExistsAsCorequisite_AddingPrerequisite_Throws()
    {
        var a = await MakeSubjectAsync("A");
        var b = await MakeSubjectAsync("B");

        await _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Corequisite));

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Prerequisite)));
        Assert.Contains("prerequisite", ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("corequisite", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    // ── 4. Circular-link check only applies to prerequisites (type 0) ─────────

    [Fact]
    public async Task AddPrerequisite_DirectCircle_Prerequisite_Throws()
    {
        // A → B (A requires B) then B → A should be rejected.
        var a = await MakeSubjectAsync("A");
        var b = await MakeSubjectAsync("B");

        await _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Prerequisite));

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.AddPrerequisiteAsync(Dto(b.SubjectID, a.SubjectID, RequisiteTypeConstants.Prerequisite)));
        Assert.Contains("circular", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task AddPrerequisite_IndirectCircle_Prerequisite_Throws()
    {
        // A → B → C, then C → A should be rejected.
        var a = await MakeSubjectAsync("A");
        var b = await MakeSubjectAsync("B");
        var c = await MakeSubjectAsync("C");

        await _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID));
        await _service.AddPrerequisiteAsync(Dto(b.SubjectID, c.SubjectID));

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.AddPrerequisiteAsync(Dto(c.SubjectID, a.SubjectID)));
        Assert.Contains("circular", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task AddPrerequisite_MutualCorequisites_AreAllowed()
    {
        // A coreq B and B coreq A must both succeed — no circular check for type 1.
        var a = await MakeSubjectAsync("A");
        var b = await MakeSubjectAsync("B");

        await _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Corequisite));
        // Should NOT throw:
        await _service.AddPrerequisiteAsync(Dto(b.SubjectID, a.SubjectID, RequisiteTypeConstants.Corequisite));

        var prereqsA = await _service.GetPrerequisitesForSubjectAsync(a.SubjectID);
        var prereqsB = await _service.GetPrerequisitesForSubjectAsync(b.SubjectID);
        Assert.Single(prereqsA);
        Assert.Single(prereqsB);
    }

    [Fact]
    public async Task AddPrerequisite_CycleThroughCorequisiteEdge_IsAllowedForPrerequisite()
    {
        // A prereq B exists, B has a coreq link back to A — the circular prereq check
        // must NOT follow the corequisite edge, so A prereq B and B coreq A are both fine.
        var a = await MakeSubjectAsync("A");
        var b = await MakeSubjectAsync("B");

        await _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Prerequisite));
        // B → A as a corequisite (not prerequisite) should succeed.
        await _service.AddPrerequisiteAsync(Dto(b.SubjectID, a.SubjectID, RequisiteTypeConstants.Corequisite));

        var prereqsB = await _service.GetPrerequisitesForSubjectAsync(b.SubjectID);
        Assert.Single(prereqsB);
        Assert.Equal(RequisiteTypeConstants.Corequisite, prereqsB[0].RequisiteType);
    }

    // ── 5. Happy-path: adding a valid prerequisite succeeds ───────────────────

    [Fact]
    public async Task AddPrerequisite_Valid_ReturnsDto()
    {
        var a = await MakeSubjectAsync("A");
        var b = await MakeSubjectAsync("B");

        var result = await _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID));

        Assert.Equal(a.SubjectID, result.SubjectID);
        Assert.Equal(b.SubjectID, result.PrerequisiteSubjectID);
        Assert.Equal(RequisiteTypeConstants.Prerequisite, result.RequisiteType);
    }

    [Fact]
    public async Task AddCorequisite_Valid_ReturnsDto()
    {
        var a = await MakeSubjectAsync("A");
        var b = await MakeSubjectAsync("B");

        var result = await _service.AddPrerequisiteAsync(Dto(a.SubjectID, b.SubjectID, RequisiteTypeConstants.Corequisite));

        Assert.Equal(RequisiteTypeConstants.Corequisite, result.RequisiteType);
    }

    // ── 6. Corequisite row does NOT block enrollment ───────────────────────────

    /// <summary>
    /// A corequisite row (RequisiteType = 1) for a subject that the student
    /// has never taken must NOT appear in ValidateEnrollmentRulesAsync findings.
    /// Prerequisite rows (RequisiteType = 0) still block enrollment.
    /// </summary>
    [Fact]
    public async Task ValidateEnrollmentRules_CorequisiteRow_DoesNotBlockEnrollment()
    {
        // Arrange: student, two terms, two subjects
        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-" + Guid.NewGuid(),
            Email = $"stu-{Guid.NewGuid():N}@test.edu",
            Role = 5,
            IsActive = true
        };
        _context.Users.Add(student);

        var term1 = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 1, IsActive = false };
        var term2 = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = "2025-2026", Semester = 2, IsActive = true };
        _context.AcademicTerms.AddRange(term1, term2);

        var mainSubject = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = "MAIN",
            SubjectTitle = "Main",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 2,
            LecUnits = 3,
            LabUnits = 0
        };
        var coSubject = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = "CO",
            SubjectTitle = "Corequisite Subject",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 2,
            LecUnits = 3,
            LabUnits = 0
        };
        _context.Subjects.AddRange(mainSubject, coSubject);

        // Corequisite link: CO is a corequisite of MAIN
        _context.SubjectPrerequisites.Add(new SubjectPrerequisite
        {
            PrerequisiteID = Guid.NewGuid(),
            SubjectID = mainSubject.SubjectID,
            PrerequisiteSubjectID = coSubject.SubjectID,
            RequisiteType = RequisiteTypeConstants.Corequisite
        });

        var mainClass = new Class
        {
            ClassID = Guid.NewGuid(),
            ClassName = "MAIN-1",
            SubjectID = mainSubject.SubjectID,
            TermID = term2.TermID,
            CreatedAt = DateTime.UtcNow
        };
        _context.Classes.Add(mainClass);

        // Clear the prior-term clearance hold so that check passes
        _context.GradeClearances.Add(new GradeClearance
        {
            ClearanceID = Guid.NewGuid(),
            UserID = student.UserID,
            TermID = term1.TermID,
            IsCleared = true,
            ClearedAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync();

        // Act: student has never taken coSubject, but it is only a corequisite — must not block
        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(
            student.UserID, mainClass.ClassID, term2.TermID);

        // Assert: no prerequisite-related findings
        Assert.DoesNotContain(findings, f => f.SubjectId == coSubject.SubjectID);
        Assert.DoesNotContain(findings, f =>
            f.Code == EnrollmentRuleCodes.PrerequisiteNotTaken ||
            f.Code == EnrollmentRuleCodes.PrerequisiteFailed ||
            f.Code == EnrollmentRuleCodes.PrerequisiteInProgress ||
            f.Code == EnrollmentRuleCodes.PrerequisiteDropped);
    }
}
