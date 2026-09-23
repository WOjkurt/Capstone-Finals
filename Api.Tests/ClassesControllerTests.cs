using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Class;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Api.Tests;

public class ClassesControllerTests
{
    private readonly Mock<IClassService> _classServiceMock;
    private readonly Mock<IClassScheduleService> _scheduleServiceMock;
    private readonly Mock<IClassRepository> _classRepoMock;
    private readonly Mock<ISubjectRepository> _subjectRepoMock;
    private readonly Mock<IProgramScopingService> _scopingServiceMock;
    private readonly Mock<IUserDetailsRepository> _userDetailsRepoMock;
    private readonly ClassesController _controller;

    public ClassesControllerTests()
    {
        _classServiceMock = new Mock<IClassService>();
        _scheduleServiceMock = new Mock<IClassScheduleService>();
        _classRepoMock = new Mock<IClassRepository>();
        _subjectRepoMock = new Mock<ISubjectRepository>();
        _scopingServiceMock = new Mock<IProgramScopingService>();
        _userDetailsRepoMock = new Mock<IUserDetailsRepository>();

        _controller = new ClassesController(
            _classServiceMock.Object,
            _scheduleServiceMock.Object,
            _scopingServiceMock.Object,
            _classRepoMock.Object,
            _subjectRepoMock.Object,
            _userDetailsRepoMock.Object);
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
    public async Task GetAll_ProgramHeadCallingWithoutTeacherId_AutoFiltersByOwnProgramSilently()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        int bsitProgramId = 1;
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        _scopingServiceMock.Setup(s => s.GetProgramIdAsync(programHeadId))
            .ReturnsAsync(bsitProgramId);

        var bsitClasses = new List<ClassDto>
        {
            new() { ClassID = Guid.NewGuid(), ClassName = "BSIT-1A", SubjectID = Guid.NewGuid(), SubjectCode = "IT101", SubjectTitle = "Intro to IT" }
        };

        _classServiceMock.Setup(s => s.GetAllAsync(null, null, null, bsitProgramId))
            .ReturnsAsync(bsitClasses);

        // Act
        var result = await _controller.GetAll(null, null, null);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var returnedClasses = Assert.IsAssignableFrom<IEnumerable<ClassDto>>(okResult.Value);
        Assert.Single(returnedClasses);

        // Verify that GetAllAsync was called with the programId parameter
        _classServiceMock.Verify(s => s.GetAllAsync(null, null, null, bsitProgramId), Times.Once);
    }

    [Fact]
    public async Task GetAll_AdminCalling_DoesNotFilterByProgram()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);

        _classServiceMock.Setup(s => s.GetAllAsync(null, null, null, null))
            .ReturnsAsync(new List<ClassDto>());

        // Act
        var result = await _controller.GetAll(null, null, null);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _classServiceMock.Verify(s => s.GetAllAsync(null, null, null, null), Times.Once);
        _scopingServiceMock.Verify(s => s.GetProgramIdAsync(It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task GetAll_ProgramHeadCallingWithOwnTeacherId_BypassesProgramScoping()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        _classServiceMock.Setup(s => s.GetAllAsync(null, null, programHeadId, null))
            .ReturnsAsync(new List<ClassDto>());

        // Act
        var result = await _controller.GetAll(null, null, programHeadId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        // Scoping service should NEVER be called since program scope is bypassed for own classes
        _scopingServiceMock.Verify(s => s.GetProgramIdAsync(It.IsAny<Guid>()), Times.Never);
        // GetAllAsync should be called with teacherUserId = programHeadId and programScope = null
        _classServiceMock.Verify(s => s.GetAllAsync(null, null, programHeadId, null), Times.Once);
    }

    [Fact]
    public async Task Create_ProgramHeadCreatingClassForSubjectInOwnProgram_ReturnsCreated()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        int bsitProgramId = 1;
        var subjectId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var dto = new CreateClassDto
        {
            SubjectID = subjectId,
            TermID = termId,
            ClassName = "BSIT 1A"
        };

        var subject = new Subject
        {
            SubjectID = subjectId,
            ProgramID = bsitProgramId,
            SubjectCode = "IT101",
            SubjectTitle = "Intro"
        };

        _subjectRepoMock.Setup(r => r.GetByIdAsync(subjectId)).ReturnsAsync(subject);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, bsitProgramId, "subject"))
            .Returns(Task.CompletedTask);

        _classServiceMock.Setup(s => s.CreateAsync(dto, programHeadId))
            .ReturnsAsync(new ClassDto { ClassID = Guid.NewGuid(), ClassName = "BSIT 1A", SubjectID = subjectId, SubjectCode = "IT101", SubjectTitle = "Intro" });

        // Act
        var result = await _controller.Create(dto);

        // Assert
        var createdResult = Assert.IsType<CreatedAtActionResult>(result);
        Assert.Equal(201, createdResult.StatusCode);
    }

    [Fact]
    public async Task Create_ProgramHeadCreatingClassForSubjectInOtherProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        int bsbaProgramId = 2;
        var subjectId = Guid.NewGuid();
        var termId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var dto = new CreateClassDto
        {
            SubjectID = subjectId,
            TermID = termId,
            ClassName = "BSBA 1A"
        };

        var subject = new Subject
        {
            SubjectID = subjectId,
            ProgramID = bsbaProgramId,
            SubjectCode = "BA101",
            SubjectTitle = "Business Intro"
        };

        _subjectRepoMock.Setup(r => r.GetByIdAsync(subjectId)).ReturnsAsync(subject);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, bsbaProgramId, "subject"))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied. You can only access subjects belonging to your academic program."));

        // Act
        var result = await _controller.Create(dto);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task Update_ProgramHeadUpdatingClassInOtherProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var classId = Guid.NewGuid();
        var existingClass = new Class
        {
            ClassID = classId,
            ClassName = "BSBA 2A",
            SubjectID = Guid.NewGuid(),
            Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = 2, SubjectCode = "BA201", SubjectTitle = "Finance" }
        };

        _classRepoMock.Setup(r => r.GetByIdAsync(classId)).ReturnsAsync(existingClass);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 2, "class"))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied."));

        var dto = new UpdateClassDto { ClassName = "BSBA 2A - Updated" };

        // Act
        var result = await _controller.Update(classId, dto);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task Delete_ProgramHeadDeletingClassInOtherProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var classId = Guid.NewGuid();
        var existingClass = new Class
        {
            ClassID = classId,
            ClassName = "BSBA 2A",
            SubjectID = Guid.NewGuid(),
            Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = 2, SubjectCode = "BA201", SubjectTitle = "Finance" }
        };

        _classRepoMock.Setup(r => r.GetByIdAsync(classId)).ReturnsAsync(existingClass);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 2, "class"))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied."));

        // Act
        var result = await _controller.Delete(classId);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
    }

    [Fact]
    public async Task Delete_AdminDeletingClassAcrossPrograms_IsAllowed()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);
        var classId = Guid.NewGuid();

        _classServiceMock.Setup(s => s.DeleteAsync(classId)).Returns(Task.CompletedTask);

        // Act
        var result = await _controller.Delete(classId);

        // Assert
        Assert.IsType<OkObjectResult>(result);
        _scopingServiceMock.Verify(s => s.EnsureProgramHeadAccessAsync(It.IsAny<Guid>(), It.IsAny<int?>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task AssignTeacher_ProgramHeadAssigningInOwnProgram_Succeeds()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var classId = Guid.NewGuid();
        var teacherId = Guid.NewGuid();
        var existingClass = new Class
        {
            ClassID = classId,
            ClassName = "BSIT 1A",
            SubjectID = Guid.NewGuid(),
            Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = 1, SubjectCode = "IT101", SubjectTitle = "Intro to IT" }
        };

        _classRepoMock.Setup(r => r.GetByIdAsync(classId)).ReturnsAsync(existingClass);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 1, "class"))
            .Returns(Task.CompletedTask);

        var teacherDetails = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = teacherId,
            Firstname = "John",
            Lastname = "Doe",
            ProgramID = 1,
            User = new User
            {
                UserID = teacherId,
                FirebaseUID = "firebase-teacher",
                Email = "teacher@dbtc-cebu.edu.ph",
                Role = RoleUtils.Teacher,
                CreatedAt = DateTime.UtcNow
            }
        };
        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(teacherId)).ReturnsAsync(teacherDetails);

        var updatedClassDto = new ClassDto
        {
            ClassID = classId,
            ClassName = "BSIT 1A",
            SubjectID = existingClass.SubjectID,
            UserID = teacherId,
            TeacherName = "Prof. Test"
        };
        _classServiceMock.Setup(s => s.AssignTeacherAsync(classId, teacherId))
            .ReturnsAsync(updatedClassDto);

        var dto = new AssignTeacherDto { UserID = teacherId };

        // Act
        var result = await _controller.AssignTeacher(classId, dto);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var returnedDto = Assert.IsType<ClassDto>(okResult.Value);
        Assert.Equal(teacherId, returnedDto.UserID);
        _classServiceMock.Verify(s => s.AssignTeacherAsync(classId, teacherId), Times.Once);
    }

    [Fact]
    public async Task AssignTeacher_ProgramHeadAssigningNonExistentUser_Returns404NotFound()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var classId = Guid.NewGuid();
        var teacherId = Guid.NewGuid();
        var existingClass = new Class
        {
            ClassID = classId,
            ClassName = "BSIT 1A",
            SubjectID = Guid.NewGuid(),
            Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = 1, SubjectCode = "IT101", SubjectTitle = "Intro to IT" }
        };

        _classRepoMock.Setup(r => r.GetByIdAsync(classId)).ReturnsAsync(existingClass);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 1, "class"))
            .Returns(Task.CompletedTask);

        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(teacherId)).ReturnsAsync((UserDetails?)null);

        var dto = new AssignTeacherDto { UserID = teacherId };

        // Act
        var result = await _controller.AssignTeacher(classId, dto);

        // Assert
        var notFoundResult = Assert.IsType<NotFoundObjectResult>(result);
        Assert.Equal(StatusCodes.Status404NotFound, notFoundResult.StatusCode);
        _classServiceMock.Verify(s => s.AssignTeacherAsync(It.IsAny<Guid>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task AssignTeacher_ProgramHeadAssigningNonTeacherRole_Returns400BadRequest()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var classId = Guid.NewGuid();
        var studentId = Guid.NewGuid();
        var existingClass = new Class
        {
            ClassID = classId,
            ClassName = "BSIT 1A",
            SubjectID = Guid.NewGuid(),
            Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = 1, SubjectCode = "IT101", SubjectTitle = "Intro to IT" }
        };

        _classRepoMock.Setup(r => r.GetByIdAsync(classId)).ReturnsAsync(existingClass);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 1, "class"))
            .Returns(Task.CompletedTask);

        var studentDetails = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = studentId,
            Firstname = "Student",
            Lastname = "User",
            ProgramID = 1,
            User = new User
            {
                UserID = studentId,
                FirebaseUID = "firebase-student",
                Email = "student@dbtc-cebu.edu.ph",
                Role = RoleUtils.Student,
                CreatedAt = DateTime.UtcNow
            }
        };
        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(studentId)).ReturnsAsync(studentDetails);

        var dto = new AssignTeacherDto { UserID = studentId };

        // Act
        var result = await _controller.AssignTeacher(classId, dto);

        // Assert
        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Equal(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
        _classServiceMock.Verify(s => s.AssignTeacherAsync(It.IsAny<Guid>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task AssignTeacher_ProgramHeadAssigningTeacherFromDifferentProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var classId = Guid.NewGuid();
        var teacherId = Guid.NewGuid();
        var existingClass = new Class
        {
            ClassID = classId,
            ClassName = "BSIT 1A",
            SubjectID = Guid.NewGuid(),
            Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = 1, SubjectCode = "IT101", SubjectTitle = "Intro to IT" }
        };

        _classRepoMock.Setup(r => r.GetByIdAsync(classId)).ReturnsAsync(existingClass);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 1, "class"))
            .Returns(Task.CompletedTask);

        // Teacher belongs to ProgramID 2 (BSBA), while class is ProgramID 1 (BSIT)
        var teacherDetails = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = teacherId,
            Firstname = "Jane",
            Lastname = "Smith",
            ProgramID = 2,
            User = new User
            {
                UserID = teacherId,
                FirebaseUID = "firebase-teacher-ba",
                Email = "teacher.ba@dbtc-cebu.edu.ph",
                Role = RoleUtils.Teacher,
                CreatedAt = DateTime.UtcNow
            }
        };
        _userDetailsRepoMock.Setup(r => r.GetByUserIdAsync(teacherId)).ReturnsAsync(teacherDetails);

        var dto = new AssignTeacherDto { UserID = teacherId };

        // Act
        var result = await _controller.AssignTeacher(classId, dto);

        // Assert
        var forbiddenResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, forbiddenResult.StatusCode);
        _classServiceMock.Verify(s => s.AssignTeacherAsync(It.IsAny<Guid>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task AssignTeacher_ProgramHeadAssigningInOtherProgram_Returns403Forbidden()
    {
        // Arrange
        var programHeadId = Guid.NewGuid();
        SetHttpContext(RoleUtils.ProgramHead, programHeadId);

        var classId = Guid.NewGuid();
        var teacherId = Guid.NewGuid();
        var existingClass = new Class
        {
            ClassID = classId,
            ClassName = "BSBA 2A",
            SubjectID = Guid.NewGuid(),
            Subject = new Subject { SubjectID = Guid.NewGuid(), ProgramID = 2, SubjectCode = "BA201", SubjectTitle = "Finance" }
        };

        _classRepoMock.Setup(r => r.GetByIdAsync(classId)).ReturnsAsync(existingClass);
        _scopingServiceMock.Setup(s => s.EnsureProgramHeadAccessAsync(programHeadId, 2, "class"))
            .ThrowsAsync(new UnauthorizedAccessException("Access denied."));

        var dto = new AssignTeacherDto { UserID = teacherId };

        // Act
        var result = await _controller.AssignTeacher(classId, dto);

        // Assert
        var statusResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status403Forbidden, statusResult.StatusCode);
        _classServiceMock.Verify(s => s.AssignTeacherAsync(It.IsAny<Guid>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task AssignTeacher_AdminAssigningAcrossPrograms_IsAllowed()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        SetHttpContext(RoleUtils.Admin, adminId);

        var classId = Guid.NewGuid();
        var teacherId = Guid.NewGuid();
        var updatedClassDto = new ClassDto
        {
            ClassID = classId,
            ClassName = "BSIT 1A",
            SubjectID = Guid.NewGuid(),
            UserID = teacherId
        };

        _classServiceMock.Setup(s => s.AssignTeacherAsync(classId, teacherId))
            .ReturnsAsync(updatedClassDto);

        var dto = new AssignTeacherDto { UserID = teacherId };

        // Act
        var result = await _controller.AssignTeacher(classId, dto);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var returnedDto = Assert.IsType<ClassDto>(okResult.Value);
        Assert.Equal(teacherId, returnedDto.UserID);
        _scopingServiceMock.Verify(s => s.EnsureProgramHeadAccessAsync(It.IsAny<Guid>(), It.IsAny<int?>(), It.IsAny<string>()), Times.Never);
    }
}
