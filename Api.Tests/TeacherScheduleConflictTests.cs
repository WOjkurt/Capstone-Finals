using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Class;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

// One teacher must not be booked into two classes at the same time in a term.
public class TeacherScheduleConflictTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly ClassScheduleService _scheduleService;
    private readonly ClassService _classService;

    private readonly Guid _termId = Guid.NewGuid();
    private readonly Guid _otherTermId = Guid.NewGuid();
    private readonly Guid _teacherId = Guid.NewGuid();
    private readonly Guid _bsitTheoClassId = Guid.NewGuid();
    private readonly Guid _bsmeTheoClassId = Guid.NewGuid();
    private readonly Guid _otherTermClassId = Guid.NewGuid();

    public TeacherScheduleConflictTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        Seed();

        var classRepo = new ClassRepository(_context);
        var scheduleRepo = new ClassScheduleRepository(_context);
        _scheduleService = new ClassScheduleService(_context, scheduleRepo, classRepo);
        _classService = new ClassService(_context, classRepo, scheduleRepo);
    }

    private void Seed()
    {
        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" },
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSME", ProgramName = "BS ME" });
        _context.AcademicTerms.AddRange(
            new AcademicTerm { TermID = _termId, SchoolYear = "2026-2027", Semester = 1 },
            new AcademicTerm { TermID = _otherTermId, SchoolYear = "2026-2027", Semester = 2 });
        _context.Users.Add(new User { UserID = _teacherId, FirebaseUID = "fb-theo", Email = "theo@dbtc-cebu.edu.ph", Role = RoleUtils.Teacher, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _teacherId, Firstname = "Ben", Lastname = "Basiced" });

        var bsitTheo = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "THEO 101A", SubjectTitle = "Theology", ProgramID = 1, YearLevel = 1, DefaultSemester = 1, IsMinor = true };
        var bsmeTheo = new Subject { SubjectID = Guid.NewGuid(), SubjectCode = "THEO 101A", SubjectTitle = "Theology", ProgramID = 2, YearLevel = 1, DefaultSemester = 1, IsMinor = true };
        _context.Subjects.AddRange(bsitTheo, bsmeTheo);

        _context.Classes.AddRange(
            // BSIT 1A theology: Ben already teaches it MWF 08:00-09:00.
            new Class { ClassID = _bsitTheoClassId, SubjectID = bsitTheo.SubjectID, TermID = _termId, ClassName = "BSIT 1A", UserID = _teacherId, CreatedAt = DateTime.UtcNow },
            // BSME 1A theology: no teacher yet.
            new Class { ClassID = _bsmeTheoClassId, SubjectID = bsmeTheo.SubjectID, TermID = _termId, ClassName = "BSME 1A", CreatedAt = DateTime.UtcNow },
            // Same time but next term: never a clash.
            new Class { ClassID = _otherTermClassId, SubjectID = bsmeTheo.SubjectID, TermID = _otherTermId, ClassName = "BSME 1A", CreatedAt = DateTime.UtcNow });

        _context.ClassSchedules.Add(new ClassSchedule
        {
            ScheduleID = Guid.NewGuid(), ClassID = _bsitTheoClassId, DaysOfWeek = "M/W/F",
            StartTime = new TimeOnly(8, 0), EndTime = new TimeOnly(9, 0), Room = "R101"
        });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private async Task AddSchedule(Guid classId, string days, int startHour, int endHour, string room = "R202")
    {
        _context.ClassSchedules.Add(new ClassSchedule
        {
            ScheduleID = Guid.NewGuid(), ClassID = classId, DaysOfWeek = days,
            StartTime = new TimeOnly(startHour, 0), EndTime = new TimeOnly(endHour, 0), Room = room
        });
        await _context.SaveChangesAsync();
    }

    private async Task SetTeacher(Guid classId)
    {
        var c = await _context.Classes.FirstAsync(x => x.ClassID == classId);
        c.UserID = _teacherId;
        await _context.SaveChangesAsync();
    }

    private static CreateClassScheduleDto Slot(Guid classId, string days, int startHour, int endHour) => new()
    {
        ClassID = classId, DaysOfWeek = days,
        StartTime = new TimeOnly(startHour, 0), EndTime = new TimeOnly(endHour, 0), Room = "R202"
    };

    // ── Assigning a teacher ─────────────────────────────────────────

    [Fact]
    public async Task AssignTeacher_OverlappingClassSameTerm_ThrowsAndLeavesClassUnassigned()
    {
        await AddSchedule(_bsmeTheoClassId, "M/W", 8, 9);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _classService.AssignTeacherAsync(_bsmeTheoClassId, _teacherId));

        Assert.Contains("Ben Basiced already teaches THEO 101A (BSIT 1A)", ex.Message);
        var bsme = await _context.Classes.AsNoTracking().FirstAsync(c => c.ClassID == _bsmeTheoClassId);
        Assert.Null(bsme.UserID);
    }

    [Fact]
    public async Task AssignTeacher_SameDaysNoTimeOverlap_Succeeds()
    {
        // 09:00 start touches the 08:00-09:00 class but does not overlap it.
        await AddSchedule(_bsmeTheoClassId, "M/W/F", 9, 10);

        var result = await _classService.AssignTeacherAsync(_bsmeTheoClassId, _teacherId);

        Assert.Equal(_teacherId, result.UserID);
    }

    [Fact]
    public async Task AssignTeacher_SameTimeDifferentDays_Succeeds()
    {
        await AddSchedule(_bsmeTheoClassId, "T/TH", 8, 9);

        var result = await _classService.AssignTeacherAsync(_bsmeTheoClassId, _teacherId);

        Assert.Equal(_teacherId, result.UserID);
    }

    [Fact]
    public async Task AssignTeacher_SameTimeDifferentTerm_Succeeds()
    {
        await AddSchedule(_otherTermClassId, "M/W/F", 8, 9);

        var result = await _classService.AssignTeacherAsync(_otherTermClassId, _teacherId);

        Assert.Equal(_teacherId, result.UserID);
    }

    [Fact]
    public async Task AssignTeacher_ClassWithNoSchedule_Succeeds()
    {
        var result = await _classService.AssignTeacherAsync(_bsmeTheoClassId, _teacherId);

        Assert.Equal(_teacherId, result.UserID);
    }

    [Fact]
    public async Task Unassigning_NeverChecksConflicts()
    {
        var result = await _classService.AssignTeacherAsync(_bsitTheoClassId, null);

        Assert.Null(result.UserID);
    }

    // ── Saving a schedule ───────────────────────────────────────────

    [Fact]
    public async Task CreateSchedule_ForClassWhoseTeacherIsBusy_Throws()
    {
        await SetTeacher(_bsmeTheoClassId);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _scheduleService.CreateAsync(Slot(_bsmeTheoClassId, "F", 8, 10)));

        Assert.Contains("already teaches THEO 101A (BSIT 1A)", ex.Message);
        Assert.False(await _context.ClassSchedules.AnyAsync(s => s.ClassID == _bsmeTheoClassId));
    }

    [Fact]
    public async Task CreateSchedule_ForClassWithoutTeacher_SkipsTeacherCheck()
    {
        var result = await _scheduleService.CreateAsync(Slot(_bsmeTheoClassId, "M/W/F", 8, 9));

        Assert.Equal(_bsmeTheoClassId, result.ClassID);
    }

    [Fact]
    public async Task UpdateSchedule_MovingIntoTeachersBusyTime_Throws()
    {
        await SetTeacher(_bsmeTheoClassId);
        var created = await _scheduleService.CreateAsync(Slot(_bsmeTheoClassId, "T/TH", 8, 9));

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => _scheduleService.UpdateAsync(created.ScheduleID, Slot(_bsmeTheoClassId, "M", 8, 9)));
    }

    [Fact]
    public async Task UpdateSchedule_ChangingOnlyTheRoom_DoesNotClashWithItself()
    {
        var existing = await _context.ClassSchedules.AsNoTracking().FirstAsync(s => s.ClassID == _bsitTheoClassId);

        var dto = Slot(_bsitTheoClassId, "M/W/F", 8, 9);
        dto.Room = "R303";
        var result = await _scheduleService.UpdateAsync(existing.ScheduleID, dto);

        Assert.Equal("R303", result.Room);
    }

    // ── A class's own times, room spelling, and time order ─────────

    [Fact]
    public async Task CreateSchedule_SameSlotTwiceOnSameClass_Throws()
    {
        await _scheduleService.CreateAsync(Slot(_bsmeTheoClassId, "T/TH", 10, 11));

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _scheduleService.CreateAsync(Slot(_bsmeTheoClassId, "T/TH", 10, 11)));

        Assert.Contains("This class already meets T/TH 10:00-11:00", ex.Message);
        Assert.Equal(1, await _context.ClassSchedules.CountAsync(s => s.ClassID == _bsmeTheoClassId));
    }

    [Fact]
    public async Task CreateSchedule_OverlapOnSameClassInAnotherRoom_StillThrows()
    {
        await _scheduleService.CreateAsync(Slot(_bsmeTheoClassId, "T", 10, 12));
        var dto = Slot(_bsmeTheoClassId, "T", 11, 13);
        dto.Room = "Lab 9";

        await Assert.ThrowsAsync<InvalidOperationException>(() => _scheduleService.CreateAsync(dto));
    }

    [Fact]
    public async Task CreateSchedule_SameClassDifferentDays_Succeeds()
    {
        await _scheduleService.CreateAsync(Slot(_bsmeTheoClassId, "T", 10, 11));

        var second = await _scheduleService.CreateAsync(Slot(_bsmeTheoClassId, "TH", 10, 11));

        Assert.Equal("TH", second.DaysOfWeek);
    }

    [Fact]
    public async Task CreateSchedule_RoomClash_IgnoresCaseAndSpaces()
    {
        // BSIT 1A already uses R101 on M/W/F 08:00-09:00.
        var dto = Slot(_bsmeTheoClassId, "F", 8, 9);
        dto.Room = " r101 ";

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => _scheduleService.CreateAsync(dto));

        Assert.Contains("already booked", ex.Message);
    }

    [Fact]
    public async Task CreateSchedule_SavesRoomTrimmed()
    {
        var dto = Slot(_bsmeTheoClassId, "S", 8, 9);
        dto.Room = "  Lab 2  ";

        var result = await _scheduleService.CreateAsync(dto);

        Assert.Equal("Lab 2", result.Room);
    }

    [Theory]
    [InlineData(10, 9)]
    [InlineData(10, 10)]
    public async Task CreateSchedule_EndNotAfterStart_Throws(int startHour, int endHour)
    {
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(
            () => _scheduleService.CreateAsync(Slot(_bsmeTheoClassId, "S", startHour, endHour)));

        Assert.Equal("End time must be after start time.", ex.Message);
    }
}
