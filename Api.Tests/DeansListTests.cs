using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

// Reports → Dean's list: term GWA, units carried and lowest grade, with every grade in.
public class DeansListTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly ReportService _reports;
    private readonly Guid _term = Guid.NewGuid();
    private readonly Dictionary<string, Guid> _subjects = new();

    public DeansListTests()
    {
        _context = new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        _reports = new ReportService(_context);
        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _term, SchoolYear = "2026-2027", Semester = 1 });
        foreach (var code in new[] { "IT 1", "IT 2", "IT 3", "IT 4", "IT 5", "PATHFIT 1" })
        {
            var id = Guid.NewGuid();
            _subjects[code] = id;
            _context.Subjects.Add(new Subject
            {
                SubjectID = id, SubjectCode = code, SubjectTitle = code, LecUnits = code.StartsWith("PATHFIT") ? 2 : 3,
                ProgramID = 1, CurriculumID = Guid.NewGuid(), YearLevel = 1, DefaultSemester = 1,
            });
        }
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    /// <summary>A student taking IT 1-5 (15 units) and PATHFIT 1, with the given grades (null = no grade yet).</summary>
    private Guid Student(string last, decimal?[] grades, decimal? pathfit = 1.0m, int dropIndex = -1)
    {
        var id = Guid.NewGuid();
        _context.Users.Add(new User { UserID = id, FirebaseUID = "fb-" + id, Email = last + "@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = id, Firstname = "A", Lastname = last, ProgramID = 1, YearLevel = 2, StudentID = "2506" + last.Length.ToString("0000") });
        // IT 1.. for each grade given, then PATHFIT 1 unless it is null (not taken).
        var taken = grades.Select((g, i) => ($"IT {i + 1}", g)).ToList();
        if (pathfit != null) taken.Add(("PATHFIT 1", pathfit));
        for (int i = 0; i < taken.Count; i++)
        {
            var (code, grade) = taken[i];
            var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = _subjects[code], TermID = _term, ClassName = "BSIT 2A", CreatedAt = DateTime.UtcNow };
            _context.Classes.Add(cls);
            var load = new StudyLoad
            {
                StudyLoadID = Guid.NewGuid(), UserID = id, ClassID = cls.ClassID, CreatedAt = DateTime.UtcNow,
                LoadStatus = i == dropIndex ? StudyLoadStatus.Dropped : StudyLoadStatus.Enrolled,
            };
            _context.StudyLoads.Add(load);
            if (grade is { } g && i != dropIndex)
                _context.Grades.Add(new Grade { GradeID = Guid.NewGuid(), StudyLoadID = load.StudyLoadID, FinalGrade = g, Remarks = g <= 3m ? 1 : 2, DateSubmitted = DateTime.UtcNow });
        }
        _context.SaveChanges();
        return id;
    }

    [Fact]
    public async Task OnlyStudentsMeetingEveryRule_AreListed_RankedByGwa()
    {
        // DBTC's rules: GWA 1.7 or better (every subject counts, PE included), no grade below 2.3, at least 15 units.
        Student("Top", new decimal?[] { 1.0m, 1.0m, 1.25m, 1.25m, 1.5m });           // GWA 20/17 = 1.18
        Student("Tied", new decimal?[] { 1.5m, 1.25m, 1.25m, 1.0m, 1.0m });          // same grades, same GWA
        Student("Good", new decimal?[] { 1.5m, 1.5m, 1.75m, 1.75m, 2.0m });          // GWA 1.62
        Student("Ok", new decimal?[] { 1.75m, 1.75m, 1.75m, 2.0m, 2.0m });           // GWA 1.75: above 1.7
        Student("PeCounts", new decimal?[] { 1.5m, 1.5m, 1.75m, 1.75m, 1.75m }, 2.25m); // 1.65 without PE, 1.72 with it
        Student("OneLow", new decimal?[] { 1.0m, 1.0m, 1.0m, 1.0m, 2.5m });         // one grade below 2.3
        Student("LowPe", new decimal?[] { 1.0m, 1.0m, 1.0m, 1.0m, 1.0m }, 2.5m);     // the lowest-grade rule covers PE too
        Student("Failed", new decimal?[] { 1.0m, 1.0m, 1.0m, 1.0m, 5.0m });
        Student("Few", new decimal?[] { 1.0m, 1.0m, 1.0m, 1.0m }, null);              // 12 units only
        Student("Dropped", new decimal?[] { 1.0m, 1.0m, 1.0m, 1.0m, 1.0m }, 1.0m, dropIndex: 4);
        Student("Waiting", new decimal?[] { 1.0m, 1.0m, 1.0m, 1.0m, null });          // a grade is missing

        var r = await _reports.GetDeansListAsync(_term, 1.7m, 15m, 2.3m);

        Assert.Equal(new[] { "Tied, A", "Top, A", "Good, A" }, r.Rows.Select(x => x.StudentName));   // tie broken by name
        Assert.Equal(new[] { 1, 1, 3 }, r.Rows.Select(x => x.Rank));
        Assert.Equal(1.18m, Math.Round(r.Rows[1].Gwa, 2));
        Assert.Equal(17m, r.Rows[1].Units);
        Assert.Equal(1.5m, r.Rows[0].LowestGrade);
        Assert.Equal(1, r.StudentsWithMissingGrades);
        Assert.Equal(10, r.StudentsChecked);   // all but Waiting
    }

    [Fact]
    public async Task TheRulesCanBeChanged()
    {
        Student("Ok", new decimal?[] { 1.75m, 1.75m, 1.75m, 2.0m, 2.0m });   // GWA 1.85
        var r = await _reports.GetDeansListAsync(_term, 2.0m, 15m, 2.5m);
        Assert.Single(r.Rows);
        Assert.Equal(2.0m, r.MaxGwa);
    }
}
