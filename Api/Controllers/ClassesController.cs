using Api.Auth;
using Api.DTOs.Class;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ClassesController : ControllerBase
{
    private readonly IClassService _classService;
    private readonly IClassScheduleService _scheduleService;
    private readonly IProgramScopingService _scopingService;
    private readonly IClassRepository _classRepository;
    private readonly ISubjectRepository _subjectRepository;
    private readonly IUserDetailsRepository _userDetailsRepository;

    public ClassesController(
        IClassService classService,
        IClassScheduleService scheduleService,
        IProgramScopingService scopingService,
        IClassRepository classRepository,
        ISubjectRepository subjectRepository,
        IUserDetailsRepository userDetailsRepository)
    {
        _classService = classService;
        _scheduleService = scheduleService;
        _scopingService = scopingService;
        _classRepository = classRepository;
        _subjectRepository = subjectRepository;
        _userDetailsRepository = userDetailsRepository;
    }

    [HttpGet]
    [EnableRateLimiting("search")]
    public async Task<IActionResult> GetAll([FromQuery] Guid? termId, [FromQuery] Guid? subjectId, [FromQuery] Guid? teacherUserId, [FromQuery] int? yearLevel)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authUserId || authUserId == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (!HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int role)
        {
            return Forbid();
        }

        int? programScope = null;
        Guid? studentScope = null;
        Guid? teacherScope = teacherUserId;

        switch (role)
        {
            case RoleUtils.Admin:
            case RoleUtils.Registrar:
            case RoleUtils.CollegeHead:
                // All classes, all filters allowed.
                break;

            case RoleUtils.ProgramHead:
                // If querying classes they teach, don't scope by program
                if (teacherUserId.HasValue && teacherUserId.Value == authUserId)
                {
                    teacherScope = authUserId;
                }
                else
                {
                    programScope = await _scopingService.GetProgramIdAsync(authUserId);
                    if (!programScope.HasValue)
                    {
                        // Program Head without an assigned program gets an empty list
                        return Ok(new List<ClassDto>());
                    }
                }
                break;

            case RoleUtils.Teacher:
                // Only classes where Class.UserID == caller.
                // If teacherUserId is sent and is not caller's id, return 403.
                if (teacherUserId.HasValue && teacherUserId.Value != authUserId)
                {
                    return Forbid();
                }
                teacherScope = authUserId;
                break;

            case RoleUtils.Student:
                // Only classes where the caller has a StudyLoad.
                studentScope = authUserId;
                break;

            default:
                return Forbid();
        }

        var classes = await _classService.GetAllAsync(termId, subjectId, teacherScope, programScope, studentScope, yearLevel);
        return Ok(classes);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authUserId || authUserId == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (!HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int role)
        {
            return Forbid();
        }

        var classDto = await _classService.GetByIdAsync(id);
        if (classDto == null)
        {
            return NotFound(new { message = $"Class with ID '{id}' was not found." });
        }

        var canAccess = await _classService.CanAccessClassAsync(id, authUserId, role);
        if (!canAccess)
        {
            return Forbid();
        }

        return Ok(classDto);
    }

    [HttpPost]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> Create([FromBody] CreateClassDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid createdByUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role && role == RoleUtils.ProgramHead)
        {
            var subject = await _subjectRepository.GetByIdAsync(dto.SubjectID);
            if (subject == null)
            {
                return NotFound(new { message = $"Subject with ID '{dto.SubjectID}' was not found." });
            }

            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(createdByUserId, subject.ProgramID, "subject");
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        try
        {
            var classDto = await _classService.CreateAsync(dto, createdByUserId);
            return CreatedAtAction(nameof(GetById), new { id = classDto.ClassID }, classDto);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpPut("{id:guid}")]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateClassDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role && role == RoleUtils.ProgramHead)
        {
            var existingClass = await _classRepository.GetByIdAsync(id);
            if (existingClass == null)
            {
                return NotFound(new { message = $"Class with ID '{id}' was not found." });
            }

            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(authUserId, existingClass.Subject?.ProgramID, "class");
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        try
        {
            var classDto = await _classService.UpdateAsync(id, dto);
            return Ok(classDto);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpPatch("{id:guid}/teacher")]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> AssignTeacher(Guid id, [FromBody] AssignTeacherDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role && role == RoleUtils.ProgramHead)
        {
            var existingClass = await _classRepository.GetByIdAsync(id);
            if (existingClass == null)
            {
                return NotFound(new { message = $"Class with ID '{id}' was not found." });
            }

            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(authUserId, existingClass.Subject?.ProgramID, "class");
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }

            if (dto.UserID.HasValue)
            {
                var teacherDetails = await _userDetailsRepository.GetByUserIdAsync(dto.UserID.Value);
                if (teacherDetails == null)
                {
                    return NotFound(new { message = $"User with ID '{dto.UserID.Value}' was not found." });
                }

                if (teacherDetails.User?.Role != RoleUtils.Teacher)
                {
                    return BadRequest(new { message = "Assigned user must have the Teacher role." });
                }

                if (teacherDetails.ProgramID != existingClass.Subject?.ProgramID)
                {
                    return StatusCode(StatusCodes.Status403Forbidden, new { message = "Teacher does not belong to the same academic program as the class." });
                }
            }
        }

        try
        {
            var classDto = await _classService.AssignTeacherAsync(id, dto.UserID);
            return Ok(classDto);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpDelete("{id:guid}")]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> Delete(Guid id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role && role == RoleUtils.ProgramHead)
        {
            var existingClass = await _classRepository.GetByIdAsync(id);
            if (existingClass == null)
            {
                return NotFound(new { message = $"Class with ID '{id}' was not found." });
            }

            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(authUserId, existingClass.Subject?.ProgramID, "class");
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        try
        {
            await _classService.DeleteAsync(id);
            return Ok(new { message = "Class deleted successfully." });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    // ── Nested schedule endpoints under /api/Classes/{classId}/schedules ──

    [HttpGet("{classId:guid}/schedules")]
    public async Task<IActionResult> GetSchedules(Guid classId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var schedules = await _scheduleService.GetByClassIdAsync(classId);
        return Ok(schedules);
    }

    [HttpPost("{classId:guid}/schedules")]
    [RequireProgramHeadOrAdmin]
    public async Task<IActionResult> CreateSchedule(Guid classId, [FromBody] CreateClassScheduleDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid authUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role && role == RoleUtils.ProgramHead)
        {
            var existingClass = await _classRepository.GetByIdAsync(classId);
            if (existingClass == null)
            {
                return NotFound(new { message = $"Class with ID '{classId}' was not found." });
            }

            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(authUserId, existingClass.Subject?.ProgramID, "class");
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        dto.ClassID = classId;
        try
        {
            var schedule = await _scheduleService.CreateAsync(dto);
            return CreatedAtAction(nameof(GetSchedules), new { classId = classId }, schedule);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    // ── POST /api/classes/open-term?dryRun=true|false ─────────────────────────

    [HttpPost("open-term")]
    public async Task<IActionResult> OpenTerm([FromQuery] bool dryRun, [FromBody] OpenTermRequestDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid callerUserId || callerUserId == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        if (!HttpContext.Items.TryGetValue("role", out var roleObj) || roleObj is not int role)
        {
            return Forbid();
        }

        // Only Admin(1), Registrar(2), Program Head(4) allowed
        if (role != RoleUtils.Admin && role != RoleUtils.Registrar && role != RoleUtils.ProgramHead)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Access denied. Admin, Registrar, or Program Head privileges required." });
        }

        // Program Head: enforce own program (server-side; ignore client-supplied programId for scoping)
        if (role == RoleUtils.ProgramHead)
        {
            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(callerUserId, dto.ProgramId, "program");
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        try
        {
            var result = await _classService.OpenTermAsync(dto, dryRun, callerUserId);
            return Ok(result);
        }
        catch (ArgumentOutOfRangeException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }
}
