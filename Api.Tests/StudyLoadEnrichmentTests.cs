using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.Repositories;
using Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Api.Tests;

public class StudyLoadEnrichmentTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly StudyLoadRepository _repo;
    private readonly Mock<IGradeClearanceService> _clearanceServiceMock;
    private readonly StudyLoadService _service;

    public StudyLoadEnrichmentTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);
        _repo = new StudyLoadRepository(_context);
        _clearanceServiceMock = new Mock<IGradeClearanceService>();
        _service = new StudyLoadService(_context, _repo, _clearanceServiceMock.Object, NullLogger<StudyLoadService>.Instance);
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    [Fact]
    public async Task GetByStudentAsync_EnrichesStudyLoadWithClassIdUnitsAndSchedules()
    {
        // Arrange
        var termId = Guid.NewGuid();
        var term = new AcademicTerm
        {
            TermID = termId,
            SchoolYear = "2025-2026",
            Semester = 1,
            IsActive = true
        };

        var studentId = Guid.NewGuid();
        var studentUser = new User
        {
            UserID = studentId,
            FirebaseUID = "fb-student-1",
            Email = "student@dbtc.edu.ph",
            Role = 5,
            IsActive = true
        };

        var subjectId = Guid.NewGuid();
        var subject = new Subject
        {
            SubjectID = subjectId,
            SubjectCode = "CS101",
            SubjectTitle = "Data Structures and Algorithms",
            LecUnits = 3.0m,
            LabUnits = 1.0m,
            LecHours = 3.0m,
            LabHours = 3.0m,
            ProgramID = 1,
            YearLevel = 2,
            DefaultSemester = 1
        };

        var classId = Guid.NewGuid();
        var enrolledClass = new Class
        {
            ClassID = classId,
            ClassName = "BSIT 2A - CS101",
            SubjectID = subjectId,
            Subject = subject,
            TermID = termId,
            Term = term,
            CreatedAt = DateTime.UtcNow
        };

        var scheduleId = Guid.NewGuid();
        var schedule = new ClassSchedule
        {
            ScheduleID = scheduleId,
            ClassID = classId,
            DaysOfWeek = "M/W/F",
            StartTime = new TimeOnly(9, 0),
            EndTime = new TimeOnly(10, 30),
            Room = "Lab 301"
        };

        var studyLoadId = Guid.NewGuid();
        var studyLoad = new StudyLoad
        {
            StudyLoadID = studyLoadId,
            UserID = studentId,
            User = studentUser,
            ClassID = classId,
            Class = enrolledClass,
            LoadStatus = 1,
            CreatedAt = DateTime.UtcNow
        };

        _context.AcademicTerms.Add(term);
        _context.Users.Add(studentUser);
        _context.Subjects.Add(subject);
        _context.Classes.Add(enrolledClass);
        _context.ClassSchedules.Add(schedule);
        _context.StudyLoads.Add(studyLoad);
        await _context.SaveChangesAsync();

        // Act
        var result = await _service.GetByStudentAsync(studentId, termId);

        // Assert
        Assert.NotNull(result);
        Assert.Single(result);

        var dto = result[0];
        Assert.Equal(studyLoadId, dto.StudyLoadId);
        Assert.Equal(classId, dto.ClassId);
        Assert.Equal("CS101", dto.SubjectCode);
        Assert.Equal("Data Structures and Algorithms", dto.SubjectTitle);
        Assert.Equal(4.0m, dto.Units); // 3.0 Lec + 1.0 Lab
        Assert.Equal("Enrolled", dto.LoadStatus);
        Assert.Equal("2025-2026 (1st Sem)", dto.TermLabel);

        // Schedules check
        Assert.NotNull(dto.Schedules);
        Assert.Single(dto.Schedules);

        var scheduleDto = dto.Schedules[0];
        Assert.Equal(scheduleId, scheduleDto.ScheduleId);
        Assert.Equal(classId, scheduleDto.ClassId);
        Assert.Equal("M/W/F", scheduleDto.DaysOfWeek);
        Assert.Equal(new TimeOnly(9, 0), scheduleDto.StartTime);
        Assert.Equal(new TimeOnly(10, 30), scheduleDto.EndTime);
        Assert.Equal("Lab 301", scheduleDto.Room);
    }
}
