using Api.Constants;
using Api.Domain.Enrollment;
using Api.DTOs.Setup;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Copying a curriculum into a new year, which is how a 2023-2024 becomes a 2026-2027 without
/// sixty subjects being retyped.
///
/// The requisites are the part worth testing. They point at SubjectIDs, and the copy has new
/// ones, so every link has to be re-resolved inside the new curriculum. Carrying the rows across
/// unchanged would leave the new curriculum's subjects pointing at the old curriculum's rows --
/// which looks correct on screen and misbehaves in the study load builder.
/// </summary>
public class CopyCurriculumTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly CurriculumService _service;
    private readonly Guid _source = Guid.NewGuid();
    private readonly Guid _otherCurriculum = Guid.NewGuid();

    public CopyCurriculumTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase("CopyCur_" + Guid.NewGuid()).Options;
        _context = new TestAppDbContext(options);

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.Curricula.AddRange(
            new Curriculum { CurriculumID = _source, ProgramID = 1, Name = "BSIT 2023", EffectiveFromYear = 2023, CreatedAt = DateTime.UtcNow },
            new Curriculum { CurriculumID = _otherCurriculum, ProgramID = 1, Name = "BSIT 2010", EffectiveFromYear = 2010, CreatedAt = DateTime.UtcNow });
        _context.SaveChanges();

        _service = new CurriculumService(_context);
    }

    public void Dispose() => _context.Dispose();

    private Guid Subject(string code, Guid curriculumId, int year = 1, int sem = 1,
        decimal lec = 3, decimal lab = 0, bool isMinor = false)
    {
        var id = Guid.NewGuid();
        _context.Subjects.Add(new Subject
        {
            SubjectID = id, SubjectCode = code, SubjectTitle = code + " title",
            LecUnits = lec, LabUnits = lab, LecHours = lec, LabHours = lab * 3,
            ProgramID = 1, CurriculumID = curriculumId,
            YearLevel = year, DefaultSemester = sem, IsMinor = isMinor,
        });
        _context.SaveChanges();
        return id;
    }

    private void Requisite(Guid subjectId, Guid requiredId, int type = RequisiteTypeConstants.Prerequisite)
    {
        _context.SubjectPrerequisites.Add(new SubjectPrerequisite
        {
            PrerequisiteID = Guid.NewGuid(),
            SubjectID = subjectId,
            PrerequisiteSubjectID = requiredId,
            RequisiteType = type,
        });
        _context.SaveChanges();
    }

    private CopyCurriculumDto Into(string name = "BSIT 2026", int year = 2026, bool dryRun = false) =>
        new() { Name = name, EffectiveFromYear = year, DryRun = dryRun };

    // ── Copying the subjects ────────────────────────────────────────────────

    [Fact]
    public async Task EverySubjectIsCopied_WithItsHoursUnitsYearAndSemester()
    {
        Subject("IT 101", _source, year: 1, sem: 1, lec: 3);
        Subject("IT 102B", _source, year: 1, sem: 1, lec: 0, lab: 2);
        Subject("IT 201", _source, year: 2, sem: 2, lec: 3);

        var result = await _service.CopyAsync(_source, Into());

        Assert.Equal(3, result.SubjectsCopied);
        var copied = await _context.Subjects.AsNoTracking()
            .Where(s => s.CurriculumID == result.CurriculumId).ToListAsync();
        var lab = copied.Single(s => s.SubjectCode == "IT 102B");
        Assert.Equal(2, lab.LabUnits);
        Assert.Equal(6, lab.LabHours);
        Assert.Equal(2, copied.Single(s => s.SubjectCode == "IT 201").YearLevel);
        Assert.Equal(2, copied.Single(s => s.SubjectCode == "IT 201").DefaultSemester);
    }

    [Fact]
    public async Task TheCopyBelongsToTheSameProgramme_AndKeepsTheNameAndYearItWasGiven()
    {
        Subject("IT 101", _source);

        var result = await _service.CopyAsync(_source, Into(name: "BSIT 2026-2027", year: 2026));

        var created = await _context.Curricula.AsNoTracking()
            .FirstAsync(c => c.CurriculumID == result.CurriculumId);
        Assert.Equal(1, created.ProgramID);
        Assert.Equal("BSIT 2026-2027", created.Name);
        Assert.Equal(2026, created.EffectiveFromYear);
    }

    [Fact]
    public async Task TheSourceIsLeftAloneEntirely()
    {
        var it101 = Subject("IT 101", _source);
        Requisite(Subject("IT 104", _source), it101);

        await _service.CopyAsync(_source, Into());

        Assert.Equal(2, await _context.Subjects.CountAsync(s => s.CurriculumID == _source));
        Assert.Equal(1, await _context.SubjectPrerequisites.CountAsync(p => p.SubjectID != Guid.Empty
            && _context.Subjects.Any(s => s.SubjectID == p.SubjectID && s.CurriculumID == _source)));
    }

    // ── Re-pointing the requisites ──────────────────────────────────────────

    [Fact]
    public async Task ARequisitePointsAtTheNewCurriculumsOwnSubject_NotTheOldOne()
    {
        var it101 = Subject("IT 101", _source);
        var it104 = Subject("IT 104", _source);
        Requisite(it104, it101);

        var result = await _service.CopyAsync(_source, Into());

        Assert.Equal(1, result.RequisitesCarried);
        var copied = await _context.Subjects.AsNoTracking()
            .Where(s => s.CurriculumID == result.CurriculumId).ToListAsync();
        var newIds = copied.Select(s => s.SubjectID).ToHashSet();

        var link = await _context.SubjectPrerequisites.AsNoTracking()
            .SingleAsync(p => newIds.Contains(p.SubjectID));
        // Both ends inside the copy. Pointing at the old rows would look right and misbehave.
        Assert.Contains(link.PrerequisiteSubjectID, newIds);
        Assert.NotEqual(it101, link.PrerequisiteSubjectID);
        Assert.NotEqual(it104, link.SubjectID);
    }

    [Fact]
    public async Task ACoRequisiteKeepsItsKind()
    {
        var lec = Subject("IT 104A", _source);
        Requisite(Subject("IT 104B", _source), lec, type: RequisiteTypeConstants.Corequisite);

        var result = await _service.CopyAsync(_source, Into());

        var newIds = (await _context.Subjects.AsNoTracking()
            .Where(s => s.CurriculumID == result.CurriculumId).Select(s => s.SubjectID).ToListAsync()).ToHashSet();
        var link = await _context.SubjectPrerequisites.AsNoTracking()
            .SingleAsync(p => newIds.Contains(p.SubjectID));
        Assert.Equal(RequisiteTypeConstants.Corequisite, link.RequisiteType);
    }

    [Fact]
    public async Task ARequisitePointingOutsideTheCurriculum_IsReportedRatherThanDropped()
    {
        var outsider = Subject("OLD 101", _otherCurriculum);
        Subject("IT 101", _source);
        Requisite(Subject("IT 104", _source), outsider);

        var result = await _service.CopyAsync(_source, Into());

        Assert.Equal(0, result.RequisitesCarried);
        // A curriculum that looks complete and is missing a rule is the bad outcome.
        var dropped = Assert.Single(result.RequisitesDropped);
        Assert.Contains("IT 104", dropped);
        Assert.Contains("OLD 101", dropped);
    }

    // ── The preview ─────────────────────────────────────────────────────────

    [Fact]
    public async Task ADryRunSaysWhatWouldHappen_AndWritesNothing()
    {
        var it101 = Subject("IT 101", _source);
        Requisite(Subject("IT 104", _source), it101);

        var result = await _service.CopyAsync(_source, Into(dryRun: true));

        Assert.True(result.DryRun);
        Assert.Null(result.CurriculumId);
        Assert.Equal(2, result.SubjectsCopied);
        Assert.Equal(1, result.RequisitesCarried);

        Assert.Equal(2, await _context.Curricula.CountAsync());
        Assert.Equal(2, await _context.Subjects.CountAsync());
    }

    [Fact]
    public async Task ADryRunCountsTheSameAsTheRealThing()
    {
        var it101 = Subject("IT 101", _source);
        Requisite(Subject("IT 104", _source), it101);
        Requisite(Subject("IT 105", _source), Subject("OLD 101", _otherCurriculum));

        var preview = await _service.CopyAsync(_source, Into(dryRun: true));
        var real = await _service.CopyAsync(_source, Into());

        Assert.Equal(preview.SubjectsCopied, real.SubjectsCopied);
        Assert.Equal(preview.RequisitesCarried, real.RequisitesCarried);
        Assert.Equal(preview.RequisitesDropped, real.RequisitesDropped);
    }

    // ── Refusals ────────────────────────────────────────────────────────────

    [Fact]
    public async Task ANameAlreadyUsedByTheSameProgramme_IsRefused()
    {
        Subject("IT 101", _source);

        var refused = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.CopyAsync(_source, Into(name: "BSIT 2010")));

        Assert.Contains("already has a curriculum", refused.Message);
        Assert.Equal(2, await _context.Curricula.CountAsync());
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task ACopyWithoutAName_IsRefused(string name)
    {
        Subject("IT 101", _source);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.CopyAsync(_source, Into(name: name)));
    }

    [Fact]
    public async Task TwoCodesThatNormaliseAlike_DoNotBreakTheCopy()
    {
        // SubjectCodes.Key turns both of these into IT101A. Keying the copy on the normalised
        // code threw ArgumentException, which the controller does not catch, so the Registrar
        // got a 500 on any curriculum holding a pair like this.
        Subject("IT 101A", _source);
        Subject("IT-101-A", _source);

        var result = await _service.CopyAsync(_source, Into());

        Assert.Equal(2, result.SubjectsCopied);
        var codes = await _context.Subjects.AsNoTracking()
            .Where(s => s.CurriculumID == result.CurriculumId)
            .Select(s => s.SubjectCode).ToListAsync();
        Assert.Equal(new[] { "IT 101A", "IT-101-A" }, codes.OrderBy(c => c));
    }

    [Fact]
    public async Task ARequisitePointingAtAnotherCurriculumsCopyOfTheSameSubject_IsRePointedHere()
    {
        // The old curriculum's IT 101 and this one's IT 101 are the same subject by code, so the
        // rule is worth keeping rather than dropping: it points at this copy's own IT 101.
        var elsewhere = Subject("IT 101", _otherCurriculum);
        Subject("IT 101", _source);
        Requisite(Subject("IT 104", _source), elsewhere);

        var result = await _service.CopyAsync(_source, Into());

        Assert.Equal(1, result.RequisitesCarried);
        Assert.Empty(result.RequisitesDropped);
        var newIds = (await _context.Subjects.AsNoTracking()
            .Where(s => s.CurriculumID == result.CurriculumId)
            .Select(s => s.SubjectID).ToListAsync()).ToHashSet();
        var link = await _context.SubjectPrerequisites.AsNoTracking()
            .SingleAsync(p => newIds.Contains(p.SubjectID));
        Assert.Contains(link.PrerequisiteSubjectID, newIds);
    }

    [Fact]
    public async Task CopyingAnEmptyCurriculum_IsRefused()
    {
        var refused = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _service.CopyAsync(_source, Into()));

        Assert.Contains("no subjects", refused.Message);
    }

    [Fact]
    public async Task CopyingSomethingThatDoesNotExist_IsNotFound()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(
            () => _service.CopyAsync(Guid.NewGuid(), Into()));
    }
}
