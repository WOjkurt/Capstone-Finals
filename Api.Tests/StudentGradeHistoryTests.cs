using Api.Auth;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

namespace Api.Tests;

// The Registrar's grade history for a student needs the term and units of every grade.
public class StudentGradeHistoryTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly GradeService _service;
    private readonly Guid _studentId = Guid.NewGuid();
    private readonly Guid _termId = Guid.NewGuid();

    public StudentGradeHistoryTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _service = new GradeService(_context, new GradeRepository(_context),
            new Mock<IGradeClearanceService>().Object, new Mock<IProgramScopingService>().Object);

        var subject = new Subject
        {
            SubjectID = Guid.NewGuid(), SubjectCode = "IT 101", SubjectTitle = "Intro", LecUnits = 2, LabUnits = 1,
            ProgramID = 1, YearLevel = 1, DefaultSemester = 1
        };
        var cls = new Class { ClassID = Guid.NewGuid(), SubjectID = subject.SubjectID, TermID = _termId, ClassName = "BSIT 1A", CreatedAt = DateTime.UtcNow };
        var load = new StudyLoad { StudyLoadID = Guid.NewGuid(), UserID = _studentId, ClassID = cls.ClassID, LoadStatus = StudyLoadStatus.Enrolled, CreatedAt = DateTime.UtcNow };

        _context.AcademicPrograms.Add(new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS IT" });
        _context.AcademicTerms.Add(new AcademicTerm { TermID = _termId, SchoolYear = "2025-2026", Semester = 2 });
        var teacherId = Guid.NewGuid();
        _context.Users.Add(new User { UserID = teacherId, FirebaseUID = "fb-t", Email = "t@dbtc-cebu.edu.ph", Role = RoleUtils.Teacher, IsActive = true });
        _context.Users.Add(new User { UserID = _studentId, FirebaseUID = "fb", Email = "s@dbtc-cebu.edu.ph", Role = RoleUtils.Student, IsActive = true });
        _context.Subjects.Add(subject);
        _context.Classes.Add(cls);
        _context.StudyLoads.Add(load);
        _context.Grades.Add(new Grade { GradeID = Guid.NewGuid(), StudyLoadID = load.StudyLoadID, FinalGrade = 5.0m, Remarks = 2, SubmittedByUserID = teacherId });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    [Fact]
    public async Task Registrar_SeesTermUnitsAndLoadStatus()
    {
        var grades = await _service.GetByStudentIdAsync(_studentId, null, Guid.NewGuid(), RoleUtils.Registrar);

        var g = Assert.Single(grades);
        Assert.Equal("IT 101", g.SubjectCode);
        Assert.Equal(3m, g.Units);
        Assert.Equal(_termId, g.TermId);
        Assert.Equal("2025-2026", g.SchoolYear);
        Assert.Equal(2, g.Semester);
        Assert.Contains("2025-2026", g.TermLabel);
        Assert.Equal(StudyLoadStatus.Enrolled, g.LoadStatus);
        Assert.Equal("Failed", g.RemarksLabel);
    }
}
