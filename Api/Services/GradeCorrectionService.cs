using Api.Auth;
using Api.Domain.Grading;
using Api.DTOs.Grading;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public class GradeCorrectionService : IGradeCorrectionService
{
    private readonly AppDbContext _context;
    private readonly IGradeCorrectionRepository _correctionRepository;
    private readonly IGradeRepository _gradeRepository;

    public GradeCorrectionService(
        AppDbContext context,
        IGradeCorrectionRepository correctionRepository,
        IGradeRepository gradeRepository)
    {
        _context = context;
        _correctionRepository = correctionRepository;
        _gradeRepository = gradeRepository;
    }

    public async Task<GradeCorrectionResponseDto> RequestCorrectionAsync(CreateGradeCorrectionDto dto, Guid authenticatedUserId)
    {
        var grade = await _context.Grades
            .AsNoTracking()
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.Class)
                    .ThenInclude(c => c!.Subject)
            .FirstOrDefaultAsync(g => g.GradeID == dto.GradeId);

        if (grade == null)
        {
            throw new KeyNotFoundException($"Grade with ID '{dto.GradeId}' was not found.");
        }

        if (grade.SubmittedByUserID != authenticatedUserId)
        {
            throw new UnauthorizedAccessException("Only the teacher who originally submitted the grade can request a correction.");
        }

        // Old Grade Validation
        if (dto.CorrectionPeriod == 1) // Midterms
        {
            if (!grade.MidtermGrade.HasValue)
            {
                throw new InvalidOperationException("Cannot request midterm grade correction because no midterm grade has been submitted yet.");
            }
            if (grade.MidtermGrade.Value != dto.OldGrade)
            {
                throw new InvalidOperationException($"Old grade mismatch: Current midterm grade is {grade.MidtermGrade.Value}, but request provided {dto.OldGrade}.");
            }
        }
        else if (dto.CorrectionPeriod == 2) // Finals
        {
            if (!grade.FinalGrade.HasValue)
            {
                throw new InvalidOperationException("Cannot request final grade correction because no final grade has been submitted yet.");
            }
            if (grade.FinalGrade.Value != dto.OldGrade)
            {
                throw new InvalidOperationException($"Old grade mismatch: Current final grade is {grade.FinalGrade.Value}, but request provided {dto.OldGrade}.");
            }
        }
        else
        {
            throw new InvalidOperationException("Invalid CorrectionPeriod. Must be 1 (Midterms) or 2 (Finals).");
        }

        // Check for existing Pending correction for this GradeID + CorrectionPeriod
        bool pendingExists = await _context.GradeCorrections
            .AsNoTracking()
            .AnyAsync(gc => gc.GradeID == dto.GradeId &&
                            gc.CorrectionPeriod == dto.CorrectionPeriod &&
                            gc.CorrectionStatus == 1);

        if (pendingExists)
        {
            throw new InvalidOperationException("A correction request for this grade period is already pending review.");
        }

        var correction = new GradeCorrection
        {
            CorrectionID = Guid.NewGuid(),
            GradeID = dto.GradeId,
            CorrectionPeriod = dto.CorrectionPeriod,
            OldGrade = dto.OldGrade,
            NewGrade = dto.NewGrade,
            Reason = dto.Reason,
            RequestedByUserID = authenticatedUserId,
            ReviewedByUserID = null,
            CorrectionStatus = 1, // Pending
            DateRequested = DateTime.UtcNow,
            DateReviewed = null
        };

        await _correctionRepository.AddAsync(correction);

        var created = await _correctionRepository.GetByIdAsync(correction.CorrectionID);
        return await MapToDtoAsync(created!);
    }

    public async Task<List<GradeCorrectionResponseDto>> GetPendingAsync()
    {
        var pendingList = await _context.GradeCorrections
            .Include(gc => gc.Grade)
                .ThenInclude(g => g!.StudyLoad)
                    .ThenInclude(sl => sl!.Class)
                        .ThenInclude(c => c!.Subject)
            .Include(gc => gc.Grade)
                .ThenInclude(g => g!.StudyLoad)
                    .ThenInclude(sl => sl!.User)
            .Include(gc => gc.RequestedByUser)
            .Include(gc => gc.ReviewedByUser)
            .Where(gc => gc.CorrectionStatus == 1)
            .ToListAsync();

        var result = new List<GradeCorrectionResponseDto>();
        foreach (var gc in pendingList)
        {
            result.Add(await MapToDtoAsync(gc));
        }

        return result;
    }

    public async Task<GradeCorrectionResponseDto> ApproveCorrectionAsync(Guid correctionId, Guid reviewerUserId)
    {
        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            var correction = await _correctionRepository.GetByIdAsync(correctionId);
            if (correction == null)
            {
                throw new KeyNotFoundException($"GradeCorrection with ID '{correctionId}' was not found.");
            }

            if (correction.CorrectionStatus != 1) // 1 = Pending
            {
                throw new InvalidOperationException($"Correction request is not in Pending status (current status: {correction.CorrectionStatus}).");
            }

            var grade = await _gradeRepository.GetByIdAsync(correction.GradeID);
            if (grade == null)
            {
                throw new KeyNotFoundException($"Linked Grade with ID '{correction.GradeID}' was not found.");
            }

            if (correction.CorrectionPeriod == 1) // Midterms
            {
                grade.MidtermGrade = correction.NewGrade;
            }
            else if (correction.CorrectionPeriod == 2) // Finals
            {
                grade.FinalGrade = correction.NewGrade;
                grade.Remarks = correction.NewGrade > 3.0m ? 2 : 1;
            }

            grade.DateSubmitted = DateTime.UtcNow;
            await _gradeRepository.UpdateAsync(grade);

            correction.CorrectionStatus = 2; // Approved
            correction.ReviewedByUserID = reviewerUserId;
            correction.DateReviewed = DateTime.UtcNow;

            await _correctionRepository.UpdateAsync(correction);

            await transaction.CommitAsync();

            var updatedCorrection = await _correctionRepository.GetByIdAsync(correctionId);
            return await MapToDtoAsync(updatedCorrection!);
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    public async Task<GradeCorrectionResponseDto> RejectCorrectionAsync(Guid correctionId, Guid reviewerUserId, string? reason)
    {
        var correction = await _correctionRepository.GetByIdAsync(correctionId);
        if (correction == null)
        {
            throw new KeyNotFoundException($"GradeCorrection with ID '{correctionId}' was not found.");
        }

        if (correction.CorrectionStatus != 1) // 1 = Pending
        {
            throw new InvalidOperationException($"Correction request is not in Pending status (current status: {correction.CorrectionStatus}).");
        }

        correction.CorrectionStatus = 3; // Rejected
        correction.ReviewedByUserID = reviewerUserId;
        correction.DateReviewed = DateTime.UtcNow;

        if (!string.IsNullOrWhiteSpace(reason))
        {
            correction.Reason = $"{correction.Reason} (Rejection Note: {reason})";
        }

        await _correctionRepository.UpdateAsync(correction);

        var updatedCorrection = await _correctionRepository.GetByIdAsync(correctionId);
        return await MapToDtoAsync(updatedCorrection!);
    }

    public async Task<GradeCorrectionResponseDto?> GetByIdAsync(Guid correctionId, Guid authenticatedUserId, int authenticatedUserRole)
    {
        var correction = await _correctionRepository.GetByIdAsync(correctionId);
        if (correction == null)
        {
            return null;
        }

        bool isRequester = correction.RequestedByUserID == authenticatedUserId;
        bool isReviewer = correction.ReviewedByUserID.HasValue && correction.ReviewedByUserID.Value == authenticatedUserId;
        bool isStaff = authenticatedUserRole == RoleUtils.Registrar || authenticatedUserRole == RoleUtils.Admin;

        if (!isRequester && !isReviewer && !isStaff)
        {
            throw new UnauthorizedAccessException("Access denied. You are not authorized to view this grade correction detail.");
        }

        return await MapToDtoAsync(correction);
    }

    public async Task<List<GradeCorrectionResponseDto>> GetMyCorrectionsAsync(Guid teacherUserId)
    {
        var list = await _context.GradeCorrections
            .Include(gc => gc.Grade)
                .ThenInclude(g => g!.StudyLoad)
                    .ThenInclude(sl => sl!.Class)
                        .ThenInclude(c => c!.Subject)
            .Include(gc => gc.Grade)
                .ThenInclude(g => g!.StudyLoad)
                    .ThenInclude(sl => sl!.User)
            .Include(gc => gc.RequestedByUser)
            .Include(gc => gc.ReviewedByUser)
            .Where(gc => gc.RequestedByUserID == teacherUserId)
            .OrderByDescending(gc => gc.DateRequested)
            .ToListAsync();

        var result = new List<GradeCorrectionResponseDto>();
        foreach (var gc in list)
        {
            result.Add(await MapToDtoAsync(gc));
        }

        return result;
    }

    // ── Helper Methods ─────────────────────────────────────────────────
    private async Task<GradeCorrectionResponseDto> MapToDtoAsync(GradeCorrection gc)
    {
        string? requesterName = await ResolveUserNameAsync(gc.RequestedByUserID);
        string? reviewerName = gc.ReviewedByUserID.HasValue ? await ResolveUserNameAsync(gc.ReviewedByUserID.Value) : null;

        string? subjectCode = null;
        string? subjectTitle = null;
        string? studentName = null;

        var fullGrade = await _context.Grades
            .AsNoTracking()
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.Class)
                    .ThenInclude(c => c!.Subject)
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.User)
            .FirstOrDefaultAsync(g => g.GradeID == gc.GradeID);

        if (fullGrade?.StudyLoad != null)
        {
            subjectCode = fullGrade.StudyLoad.Class?.Subject?.SubjectCode;
            subjectTitle = fullGrade.StudyLoad.Class?.Subject?.SubjectTitle;
            if (fullGrade.StudyLoad.UserID != Guid.Empty)
            {
                studentName = await ResolveUserNameAsync(fullGrade.StudyLoad.UserID);
            }
        }

        return new GradeCorrectionResponseDto
        {
            CorrectionId = gc.CorrectionID,
            GradeId = gc.GradeID,
            CorrectionPeriod = gc.CorrectionPeriod,
            CorrectionPeriodLabel = FormatPeriod(gc.CorrectionPeriod),
            OldGrade = gc.OldGrade,
            NewGrade = gc.NewGrade,
            Reason = gc.Reason,
            RequestedByUserID = gc.RequestedByUserID,
            RequesterName = requesterName,
            ReviewedByUserID = gc.ReviewedByUserID,
            ReviewerName = reviewerName,
            CorrectionStatus = gc.CorrectionStatus,
            CorrectionStatusLabel = FormatStatus(gc.CorrectionStatus),
            DateRequested = gc.DateRequested,
            DateReviewed = gc.DateReviewed,
            SubjectCode = subjectCode,
            SubjectTitle = subjectTitle,
            StudentName = studentName
        };
    }

    private async Task<string?> ResolveUserNameAsync(Guid userId)
    {
        var ud = await _context.UserDetails
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.UserID == userId);

        return ud != null ? $"{ud.Firstname} {ud.Lastname}" : null;
    }

    private static string FormatPeriod(int period)
    {
        return period switch
        {
            1 => "Midterms",
            2 => "Finals",
            _ => $"Period {period}"
        };
    }

    private static string FormatStatus(int status)
    {
        return status switch
        {
            1 => "Pending",
            2 => "Approved",
            3 => "Rejected",
            _ => $"Status {status}"
        };
    }
}
