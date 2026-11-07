using Api.Auth;
using Api.Domain.Audit;
using Api.Domain.Enrollment;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Api.Controllers;

[ApiController]
[Route("api/studyloads")]
public class StudyLoadsController : ControllerBase
{
    private readonly IStudyLoadService _studyLoadService;
    private readonly IClassRepository _classRepository;
    private readonly IUserDetailsRepository _userDetailsRepository;
    private readonly IProgramScopingService _scopingService;

    public StudyLoadsController(
        IStudyLoadService studyLoadService,
        IClassRepository classRepository,
        IUserDetailsRepository userDetailsRepository,
        IProgramScopingService scopingService)
    {
        _studyLoadService = studyLoadService;
        _classRepository = classRepository;
        _userDetailsRepository = userDetailsRepository;
        _scopingService = scopingService;
    }

    [HttpGet("proposed-block")]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> GetProposedBlock([FromQuery] Guid userId, [FromQuery] Guid termId)
    {
        try
        {
            var block = await _studyLoadService.GetProposedBlockAsync(userId, termId);
            return Ok(block);
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

    [HttpPost("enroll-batch")]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> EnrollBatch([FromBody] EnrollBatchRequestDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid createdByUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        int? callerRole = HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role ? role : null;

        try
        {
            bool pending = callerRole == RoleUtils.CollegeHead || dto.AsPending;
            var changes = this.LoadChanges();
            // Enrolling more subjects for a student who is already enrolled this term is an "add".
            bool isAdd = !pending && changes != null && await changes.IsEnrolledInTermAsync(dto.UserId, dto.TermId);
            if (isAdd && string.IsNullOrWhiteSpace(dto.ChangeReason))
            {
                return BadRequest(new { message = AddReasonRequired });
            }

            var startedAt = DateTime.UtcNow;
            var result = await _studyLoadService.EnrollBatchAsync(dto, createdByUserId, callerRole);

            if (isAdd)
            {
                foreach (var r in result.Where(r => r.Enrolled && r.StudyLoadId.HasValue))
                {
                    await changes!.RecordAddedIfNewAsync(r.StudyLoadId!.Value, startedAt, dto.ChangeReason, createdByUserId);
                }
            }

            var log = this.ActivityLog();
            int saved = result.Count(r => r.Enrolled);
            if (log != null && saved > 0)
            {
                await log.LogAsync(createdByUserId, ActivityActions.LoadsSaved,
                    pending ? $"Saved {saved} subject(s) as Pending"
                    : isAdd ? $"Added {saved} subject(s) after enrollment: {dto.ChangeReason!.Trim()}"
                    : $"Enrolled {saved} subject(s)",
                    dto.UserId, dto.TermId);
                var overload = await log.RecentOverloadAsync(dto.UserId, dto.TermId, createdByUserId, startedAt);
                if (overload.HasValue)
                {
                    await log.LogAsync(createdByUserId, ActivityActions.OverloadApproved,
                        $"Approved overload {overload.Value.Units:0.#} of {overload.Value.MaxUnits:0.#} units: {overload.Value.Reason}",
                        dto.UserId, dto.TermId);
                }
            }
            return Ok(result);
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

    [HttpPost("enroll-single")]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> EnrollSingle([FromBody] EnrollSingleRequestDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid createdByUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        int? callerRole = HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role ? role : null;

        try
        {
            var changes = this.LoadChanges();
            var termId = changes != null ? await changes.TermOfClassAsync(dto.ClassId) : null;
            bool isAdd = callerRole != RoleUtils.CollegeHead && !dto.AsPending && termId.HasValue &&
                         await changes!.IsEnrolledInTermAsync(dto.UserId, termId.Value);
            if (isAdd && string.IsNullOrWhiteSpace(dto.ChangeReason))
            {
                return BadRequest(new { message = AddReasonRequired });
            }

            var startedAt = DateTime.UtcNow;
            var result = await _studyLoadService.EnrollSingleAsync(dto, createdByUserId, callerRole);
            if (isAdd && result.Success && result.StudyLoadId.HasValue)
            {
                await changes!.RecordAddedIfNewAsync(result.StudyLoadId.Value, startedAt, dto.ChangeReason, createdByUserId);
            }

            var log = this.ActivityLog();
            if (log != null && result.Success && result.StudyLoadId.HasValue)
            {
                var load = await log.DescribeLoadAsync(result.StudyLoadId.Value);
                if (load.HasValue)
                {
                    await log.LogAsync(createdByUserId,
                        dto.Force ? ActivityActions.ForcedEnrollment : ActivityActions.LoadsSaved,
                        dto.Force
                            ? $"Forced {load.Value.Label}: {dto.ForceReason}"
                            : isAdd
                                ? $"Added {load.Value.Label} after enrollment: {dto.ChangeReason!.Trim()}"
                                : $"Added {load.Value.Label} as {ActivityLogControllerExtensions.LoadStatusText(load.Value.Status)}",
                        load.Value.StudentId, load.Value.TermId);
                }
            }
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("finalize")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> FinalizeBatch([FromBody] FinalizeStudyLoadsRequestDto dto)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid callerUserId)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        int? callerRole = HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role ? role : null;

        try
        {
            var changes = this.LoadChanges();
            var newestEnrolledAt = changes != null ? await changes.NewestEnrolledAtAsync(dto.UserId, dto.TermId) : null;
            var result = await _studyLoadService.FinalizeBatchAsync(dto, callerUserId, callerRole);
            if (!result.Success)
            {
                return BadRequest(result);
            }
            if (changes != null && newestEnrolledAt.HasValue)
            {
                await changes.RecordLateAddsAsync(result.FinalizedLoads.Select(l => l.StudyLoadId), newestEnrolledAt.Value, callerUserId);
            }
            var log = this.ActivityLog();
            if (log != null && result.FinalizedLoads.Count > 0)
            {
                await log.LogAsync(callerUserId, ActivityActions.LoadsFinalized,
                    $"Finalized {result.FinalizedLoads.Count} subject(s): {string.Join(", ", result.FinalizedLoads.Select(l => l.SubjectCode))}",
                    dto.UserId, dto.TermId);
            }
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("year-level-suggestions")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> GetYearLevelSuggestions([FromQuery] int programId, [FromQuery] int? yearLevel)
    {
        return Ok(await _studyLoadService.GetYearLevelSuggestionsAsync(programId, yearLevel));
    }

    [HttpPost("apply-year-levels")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> ApplyYearLevels([FromBody] ApplyYearLevelsRequestDto dto)
    {
        try
        {
            var log = this.ActivityLog();
            var before = log != null
                ? await log.YearLevelsAsync(dto.Changes.Select(c => c.UserId))
                : new Dictionary<Guid, int?>();
            var updated = await _studyLoadService.ApplyYearLevelsAsync(dto.Changes);
            if (log != null)
            {
                foreach (var c in dto.Changes)
                {
                    var old = before.GetValueOrDefault(c.UserId);
                    await log.LogAsync(this.CallerId(), ActivityActions.YearLevelChanged,
                        $"Year level {(old.HasValue ? old.Value.ToString() : "not set")} -> {c.YearLevel} (Promotion page)", c.UserId);
                }
            }
            return Ok(new { updated });
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

    [HttpGet("unit-limit")]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> GetUnitLimit([FromQuery] Guid userId, [FromQuery] Guid termId)
    {
        try
        {
            return Ok(await _studyLoadService.GetUnitLimitAsync(userId, termId));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpGet("year-level-suggestion")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> GetYearLevelSuggestion([FromQuery] Guid userId)
    {
        try
        {
            return Ok(await _studyLoadService.GetYearLevelSuggestionAsync(userId));
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

    [HttpGet("pending-summary")]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> GetPendingSummary([FromQuery] Guid? termId)
    {
        try
        {
            var summary = await _studyLoadService.GetPendingSummaryAsync(termId);
            return Ok(summary);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPatch("{id:guid}/status")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> UpdateStatus(Guid id, [FromBody] UpdateStudyLoadStatusDto dto)
    {
        int? callerRole = HttpContext.Items.TryGetValue("role", out var roleObj) && roleObj is int role ? role : null;
        if ((dto.LoadStatus == StudyLoadStatus.Dropped || dto.LoadStatus == StudyLoadStatus.Withdrawn) &&
            string.IsNullOrWhiteSpace(dto.Reason))
        {
            return BadRequest(new { message = "Give a reason for dropping or withdrawing the subject." });
        }
        try
        {
            var log = this.ActivityLog();
            var changes = this.LoadChanges();
            var before = log != null ? await log.DescribeLoadAsync(id) : null;
            var oldStatus = changes != null ? await changes.StatusOfAsync(id) : null;
            var result = await _studyLoadService.UpdateStatusAsync(id, dto.LoadStatus, callerRole);

            var kind = dto.LoadStatus switch
            {
                StudyLoadStatus.Dropped => StudyLoadChangeKinds.Dropped,
                StudyLoadStatus.Withdrawn => StudyLoadChangeKinds.Withdrawn,
                StudyLoadStatus.Enrolled when oldStatus is StudyLoadStatus.Dropped or StudyLoadStatus.Withdrawn => StudyLoadChangeKinds.Reenrolled,
                _ => null
            };
            if (changes != null && kind != null && oldStatus != dto.LoadStatus)
            {
                await changes.RecordAsync(id, kind, dto.Reason, this.CallerId());
            }

            if (log != null && before.HasValue && before.Value.Status != dto.LoadStatus)
            {
                var why = string.IsNullOrWhiteSpace(dto.Reason) ? "" : $" ({dto.Reason.Trim()})";
                await log.LogAsync(this.CallerId(), ActivityActions.LoadStatusChanged,
                    $"{before.Value.Label}: {ActivityLogControllerExtensions.LoadStatusText(before.Value.Status)} -> {ActivityLogControllerExtensions.LoadStatusText(dto.LoadStatus)}{why}",
                    before.Value.StudentId, before.Value.TermId);
            }
            return Ok(result);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    private const string AddReasonRequired = "This student is already enrolled for the term. Give a reason for adding the subject.";

    /// <summary>Subjects added, dropped, withdrawn or re-enrolled after enrollment (the Adding/Dropping form).</summary>
    [HttpGet("changes")]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> GetChanges([FromQuery] Guid userId, [FromQuery] Guid termId)
    {
        var changes = this.LoadChanges();
        return Ok(changes == null ? new List<StudyLoadChangeDto>() : await changes.GetAsync(userId, termId));
    }

    [HttpGet("student/{userId:guid}")]
    [EnableRateLimiting("search")]
    public async Task<IActionResult> GetByStudent(Guid userId, [FromQuery] Guid termId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var authUserIdObj) || authUserIdObj is not Guid authUserId ||
            !HttpContext.Items.TryGetValue("role", out var authRoleObj) || authRoleObj is not int authRole)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        bool isSelf = authUserId == userId;
        bool isStaff = authRole == RoleUtils.Registrar || authRole == RoleUtils.Admin || authRole == RoleUtils.ProgramHead || authRole == RoleUtils.CollegeHead;

        if (!isSelf && !isStaff)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Access denied." });
        }

        if (authRole == RoleUtils.ProgramHead && !isSelf)
        {
            var studentDetails = await _userDetailsRepository.GetByUserIdAsync(userId);
            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(authUserId, studentDetails?.ProgramID, "student");
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        try
        {
            bool isStudentCaller = authRole == RoleUtils.Student;
            var loads = await _studyLoadService.GetByStudentAsync(userId, termId, isStudentCaller, authRole);
            return Ok(loads);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpGet("class/{classId:guid}")]
    [EnableRateLimiting("search")]
    public async Task<IActionResult> GetByClass(Guid classId)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var authUserIdObj) || authUserIdObj is not Guid authUserId ||
            !HttpContext.Items.TryGetValue("role", out var authRoleObj) || authRoleObj is not int authRole)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var targetClass = await _classRepository.GetByIdAsync(classId);
        if (targetClass == null)
        {
            return NotFound(new { message = $"Class with ID '{classId}' was not found." });
        }

        bool isRegistrarOrAdminOrCollegeHead = authRole == RoleUtils.Registrar || authRole == RoleUtils.Admin || authRole == RoleUtils.CollegeHead;
        bool isTeacher = targetClass.UserID.HasValue && targetClass.UserID.Value == authUserId;
        bool isProgramHead = authRole == RoleUtils.ProgramHead;

        if (!isRegistrarOrAdminOrCollegeHead && !isTeacher && !isProgramHead)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Access denied." });
        }

        if (isProgramHead && !isTeacher)
        {
            try
            {
                await _scopingService.EnsureProgramHeadAccessAsync(authUserId, targetClass.Subject?.ProgramID, "class");
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        bool excludePending = authRole == RoleUtils.Teacher;
        var loads = await _studyLoadService.GetByClassAsync(classId, excludePending, authRole);
        return Ok(loads);
    }
}
