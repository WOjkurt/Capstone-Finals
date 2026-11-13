using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

// Records → Candidates for graduation: final-year students and what each still needs.
public class GraduationCandidatesTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly StudentRecordService _records;
    private readonly Guid _curriculum = Guid.NewGuid();
    private readonly Guid _term = Guid.NewGuid();
    private readonly Dictionary<string, Guid> _subjects = new();
    private readonly Guid _done = Guid.NewGuid(), _finishing = Guid.NewGuid(), _lacking = Guid.NewGuid(), _secondYear = Guid.NewGuid();

    public GraduationCandidatesTests()
    {
        _context = new TestAppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        _records = new StudentRecordService(_context);
        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.Curricula.Add(new Curriculum { CurriculumID = _curriculum, ProgramID = 1, Name = "BSIT 2023", EffectiveFromYear = 2023 });
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _term, SchoolYear = "2026-2027", Semester = 1, IsActive = true });
        foreach (var (code, year) in new[] { ("IT 101", 1), ("IT 301", 3), ("CAP 401", 4) })
        {
            var id = Guid.NewGuid();
            _subjects[code] = id;
            _context.Subjects.Add(new Subject
            {
                SubjectID = id, SubjectCode = code, SubjectTitle = code, LecUnits = 3, ProgramID = 1, CurriculumID = _curriculum,
                YearLevel = year, DefaultSemester = 1,
            });
        }
        Student(_done, "Ana", "Cruz", 4);
        Student(_finishing, "Ben", "Reyes", 4);
        Student(_lacking, "Cara", "Lim", 4);
        Student(_secondYear, "Dan", "Uy", 3);
        _context.SaveChanges();

        foreach (var code in new[] { "IT 101", "IT 301", "CAP 401" }) Take(_done, code, 1.5m);
        Take(_finishing, "IT 101", 2.0m);
        Take(_finishing, "IT 301", 2.0m);
        Take(_finishing, "CAP 401", null);          // taking it now
        Take(_lacking, "IT 101", 2.0m);
        Take(_lacking, "IT 301", 5.0m);             // failed, not retaken
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private void Student(Guid id, string first, string last, int year)
    {
        _context.Users.Add(new User { UserID = id, FirebaseUID = "fb-" + id, Email = first.ToLower() + "@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(), UserID = id, Firstname = first, Lastname = last, ProgramID = 1, YearLevel = year, CurriculumID = _curriculum,
            StudentID = "2506" + Math.Abs(id.GetHashCode() % 10000).ToString("0000"),
        });
    }

    private void Take(Guid student, string code, decimal? grade)
    {
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = _subjects[code], TermID = _term, ClassName = "BSIT 4A", CreatedAt = DateTime.UtcNow };
        _context.Classes.Add(cls);
        var load = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = student, ClassID = cls.ClassID, LoadStatus = StudyLoadStatus.Enrolled, CreatedAt = DateTime.UtcNow };
        _context.StudyLoads.Add(load);
        if (grade is { } g)
        {
            _context.Grades.Add(new Grade { GradeID = Guid.NewGuid(), StudyLoadID = load.StudyLoadID, FinalGrade = g, Remarks = g <= 3m ? 1 : 2, DateSubmitted = DateTime.UtcNow });
        }
    }

    [Fact]
    public async Task FinalYearStudents_AreSortedIntoCompleteFinishingAndLacking()
    {
        var r = await _records.GetGraduationCandidatesAsync(null);

        Assert.Equal(new[] { "Cruz", "Lim", "Reyes" }, r.Rows.Select(x => x.Lastname));   // Uy is in 3rd year
        Assert.Equal((1, 1, 1), (r.Complete, r.FinishingThisTerm, r.Lacking));

        var ana = r.Rows.Single(x => x.UserId == _done);
        Assert.Equal("Complete", ana.Status);
        Assert.Equal(9m, ana.EarnedUnits);

        var ben = r.Rows.Single(x => x.UserId == _finishing);
        Assert.Equal("FinishingThisTerm", ben.Status);
        Assert.Equal("CAP 401", Assert.Single(ben.InProgress).SubjectCode);

        var cara = r.Rows.Single(x => x.UserId == _lacking);
        Assert.Equal("Lacking", cara.Status);
        Assert.Equal(new[] { ("IT 301", "Failed"), ("CAP 401", "NotTaken") }, cara.LackingSubjects.Select(x => (x.SubjectCode, x.Status)));
    }

    [Fact]
    public async Task OtherProgram_HasNoCandidates()
    {
        var r = await _records.GetGraduationCandidatesAsync(2);
        Assert.Empty(r.Rows);
    }
}
