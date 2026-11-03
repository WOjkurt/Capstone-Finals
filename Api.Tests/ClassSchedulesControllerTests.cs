using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.DTOs.Class;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Api.Tests;

public class ClassSchedulesControllerTests
{
    private readonly Mock<IClassScheduleService> _scheduleServiceMock;
    private readonly Mock<IClassScheduleRepository> _scheduleRepoMock;
    private readonly Mock<IClassRepository> _classRepoMock;
    private readonly Mock<IProgramScopingService> _scopingServiceMock;
    private readonly ClassSchedulesController _controller;

    public ClassSchedulesControllerTests()
    {
        _scheduleServiceMock = new Mock<IClassScheduleService>();
        _scheduleRepoMock = new Mock<IClassScheduleRepository>();
        _classRepoMock = new Mock<IClassRepository>();
        _scopingServiceMock = new Mock<IProgramScopingService>();

        _controller = new ClassSchedulesController(
            _scheduleServiceMock.Object,
            _scheduleRepoMock.Object,
            _classRepoMock.Object,
            _scopingServiceMock.Object);
    }

    private void SetHttpContext(int role, Guid userId)
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Items["role"] = role;
        httpContext.Items["user_id"] = userId;
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = httpContext
        };
    }

    [Fact]
    public async Task Update_ProgramHeadUpdatingScheduleInOtherProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var scheduleId = Guid.NewGuid();
        var existingSchedule = new ClassSchedule
        {
            ScheduleID = scheduleId,
            ClassID = Guid.NewGuid(),
            DaysOfWeek = "MWF",
            StartTime = new TimeOnly(8, 0),
            EndTime = new TimeOnly(9, 30),
            Room = "Room 101",
            Class = new Class
            {
                ClassID = Guid.NewGuid(),
                ClassName = "BSBA 1A",
                Subject = new Subject
                {
                    SubjectID = Guid.NewGuid(),
                    ProgramID = 2,
                    SubjectCode = "BA101",
                    SubjectTitle = "Business Intro"
                }
            }
        };

        _scheduleRepoMock.Setup(r => r.GetByIdAsync(scheduleId)).ReturnsAsync(existingSchedule);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 2, "schedule"))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied."));

        var dto = new CreateClassScheduleDto
        {
            DaysOfWeek = "MWF",
            StartTime = new TimeOnly(8, 0),
            EndTime = new TimeOnly(9, 30),
            Room = "Room 101"
        };

        // Act
        var result = await _controller.Update(scheduleId, dto);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task Update_ProgramHeadReassigningScheduleToClassInOtherProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        int bsitProgramId = 1;
        int bsbaProgramId = 2;
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var scheduleId = Guid.NewGuid();
        var originalClassId = Guid.NewGuid();
        var targetClassId = Guid.NewGuid();

        var existingSchedule = new ClassSchedule
        {
            ScheduleID = scheduleId,
            ClassID = originalClassId,
            DaysOfWeek = "MWF",
            StartTime = new TimeOnly(8, 0),
            EndTime = new TimeOnly(9, 30),
            Room = "Room 101",
            Class = new Class
            {
                ClassID = originalClassId,
                ClassName = "BSIT 1A",
                Subject = new Subject
                {
                    SubjectID = Guid.NewGuid(),
                    ProgramID = bsitProgramId,
                    SubjectCode = "IT101",
                    SubjectTitle = "Intro"
                }
            }
        };

        var targetClassInOtherProgram = new Class
        {
            ClassID = targetClassId,
            ClassName = "BSBA 1A",
            Subject = new Subject
            {
                SubjectID = Guid.NewGuid(),
                ProgramID = bsbaProgramId,
                SubjectCode = "BA101",
                SubjectTitle = "Business Intro"
            }
        };

        _scheduleRepoMock.Setup(r => r.GetByIdAsync(scheduleId)).ReturnsAsync(existingSchedule);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, bsitProgramId, "schedule"))
            .Returns(Task.CompletedTask);

        _classRepoMock.Setup(r => r.GetByIdAsync(targetClassId)).ReturnsAsync(targetClassInOtherProgram);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, bsbaProgramId, "class"))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied."));

        var dto = new CreateClassScheduleDto
        {
            ClassID = targetClassId,
            DaysOfWeek = "TTH",
            StartTime = new TimeOnly(10, 0),
            EndTime = new TimeOnly(11, 30),
            Room = "Room 202"
        };

        // Act
        var result = await _controller.Update(scheduleId, dto);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task Delete_ProgramHeadDeletingScheduleInOtherProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var scheduleId = Guid.NewGuid();
        var existingSchedule = new ClassSchedule
        {
            ScheduleID = scheduleId,
            ClassID = Guid.NewGuid(),
            DaysOfWeek = "MWF",
            StartTime = new TimeOnly(8, 0),
            EndTime = new TimeOnly(9, 30),
            Room = "Room 101",
            Class = new Class
            {
                ClassID = Guid.NewGuid(),
                ClassName = "BSBA 1A",
                Subject = new Subject
                {
                    SubjectID = Guid.NewGuid(),
                    ProgramID = 2,
                    SubjectCode = "BA101",
                    SubjectTitle = "Business Intro"
                }
            }
        };

        _scheduleRepoMock.Setup(r => r.GetByIdAsync(scheduleId)).ReturnsAsync(existingSchedule);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 2, "schedule"))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied."));

        // Act
        var result = await _controller.Delete(scheduleId);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task Delete_AdminDeletingScheduleInAnyProgram_IsAllowed()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);
        var scheduleId = Guid.NewGuid();

        _scheduleServiceMock.Setup(s => s.DeleteAsync(scheduleId)).Returns(Task.CompletedTask);

        // Act
        var result = await _controller.Delete(scheduleId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.EnsureProgramHeadAccessAsync(It.IsAny<Guid>(), It.IsAny<int?>(), It.IsAny<string>()), Times.Never);
    }

    // ── Minor subjects: schedules belong to the College Head (Stage 9C) ──

    private ClassSchedule SetupScheduleOnClass(Guid scheduleId, int programId, bool isMinor)
    {
        var schedule = new ClassSchedule
        {
            ScheduleID = scheduleId,
            ClassID = Guid.NewGuid(),
            DaysOfWeek = "M/W/F",
            StartTime = new TimeOnly(8, 0),
            EndTime = new TimeOnly(9, 0),
            Room = "R101",
            Class = new Class
            {
                ClassID = Guid.NewGuid(),
                ClassName = "BSIT 1A",
                SubjectID = Guid.NewGuid(),
                Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = programId, SubjectCode = isMinor ? "THEO 101A" : "IT101", SubjectTitle = "Subject", IsMinor = isMinor }
            }
        };
        _scheduleRepoMock.Setup(r => r.GetByIdAsync(scheduleId)).ReturnsAsync(schedule);
        return schedule;
    }

    private static CreateClassScheduleDto ScheduleDto(Guid classId) => new()
    {
        ClassID = classId, DaysOfWeek = "T/TH", StartTime = new TimeOnly(10, 0), EndTime = new TimeOnly(11, 0), Room = "R102"
    };

    [Fact]
    public async Task Update_ProgramHeadOnMinorSubject_Returns403()
    {
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);
        var scheduleId = Guid.NewGuid();
        var schedule = SetupScheduleOnClass(scheduleId, programId: 1, isMinor: true);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 1, "schedule")).Returns(Task.CompletedTask);

        var result = await _controller.Update(scheduleId, ScheduleDto(schedule.ClassID));

        var obj = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, obj.StatusCode);
        Assert.Contains("College Head", obj.Value!.ToString());
        _scheduleServiceMock.Verify(s => s.UpdateAsync(It.IsAny<Guid>(), It.IsAny<CreateClassScheduleDto>()), Times.Never);
    }

    [Fact]
    public async Task Delete_ProgramHeadOnMinorSubject_Returns403()
    {
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);
        var scheduleId = Guid.NewGuid();
        SetupScheduleOnClass(scheduleId, programId: 1, isMinor: true);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 1, "schedule")).Returns(Task.CompletedTask);

        var result = await _controller.Delete(scheduleId);

        var obj = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, obj.StatusCode);
        _scheduleServiceMock.Verify(s => s.DeleteAsync(It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task Update_ProgramHeadOnMajorSubject_StillSucceeds()
    {
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);
        var scheduleId = Guid.NewGuid();
        var schedule = SetupScheduleOnClass(scheduleId, programId: 1, isMinor: false);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 1, "schedule")).Returns(Task.CompletedTask);
        var dto = ScheduleDto(schedule.ClassID);
        _scheduleServiceMock.Setup(s => s.UpdateAsync(scheduleId, dto))
            .ReturnsAsync(new ClassScheduleDto { ScheduleID = scheduleId, ClassID = schedule.ClassID, DaysOfWeek = "T/TH", Room = "R102" });

        var result = await _controller.Update(scheduleId, dto);

        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task Update_CollegeHeadOnMinorSubject_Succeeds_WithoutProgramScoping()
    {
        SetHttpContext(RoleUtils.CollegeHead, Guid.NewGuid());
        var scheduleId = Guid.NewGuid();
        var schedule = SetupScheduleOnClass(scheduleId, programId: 2, isMinor: true);
        var dto = ScheduleDto(schedule.ClassID);
        _scheduleServiceMock.Setup(s => s.UpdateAsync(scheduleId, dto))
            .ReturnsAsync(new ClassScheduleDto { ScheduleID = scheduleId, ClassID = schedule.ClassID, DaysOfWeek = "T/TH", Room = "R102" });

        var result = await _controller.Update(scheduleId, dto);

        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.EnsureProgramHeadAccessAsync(It.IsAny<Guid>(), It.IsAny<int?>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task Delete_CollegeHeadOnMinorSubject_Succeeds()
    {
        SetHttpContext(RoleUtils.CollegeHead, Guid.NewGuid());
        var scheduleId = Guid.NewGuid();
        SetupScheduleOnClass(scheduleId, programId: 2, isMinor: true);
        _scheduleServiceMock.Setup(s => s.DeleteAsync(scheduleId)).Returns(Task.CompletedTask);

        var result = await _controller.Delete(scheduleId);

        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task Update_TeacherClash_Returns409()
    {
        SetHttpContext(RoleUtils.CollegeHead, Guid.NewGuid());
        var scheduleId = Guid.NewGuid();
        var schedule = SetupScheduleOnClass(scheduleId, programId: 2, isMinor: true);
        var dto = ScheduleDto(schedule.ClassID);
        _scheduleServiceMock.Setup(s => s.UpdateAsync(scheduleId, dto))
            .ThrowsAsync(new InvalidOperationException("Ben Basiced already teaches THEO 101A (BSIT 1A) M/W/F 08:00-09:00 this term."));

        var result = await _controller.Update(scheduleId, dto);

        var conflict = Assert.IsType<ConflictObjectResult>(result);
        Assert.Contains("already teaches", conflict.Value!.ToString());
    }
}
