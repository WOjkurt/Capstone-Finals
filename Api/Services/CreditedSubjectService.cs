using Api.Auth;
using Api.Common;
using Api.Domain.Enrollment;
using Api.DTOs.Credits;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface ICreditedSubjectService
{
    Task<List<CreditedSubjectDto>> GetByStudentAsync(Guid userId);
    Task<CreditedSubjectDto> CreateAsync(CreateCreditedSubjectDto dto, Guid recordedByUserId);
    Task<(CreditedSubject Credit, Subject Subject)> BuildAsync(CreateCreditedSubjectDto dto, Guid recordedByUserId);
    Task<CreditedSubjectDto> UpdateAsync(Guid creditedSubjectId, UpdateCreditedSubjectDto dto);
    Task DeleteAsync(Guid creditedSubjectId);
    Task<CreditedSubjectDto?> GetByIdAsync(Guid creditedSubjectId);
}

public class CreditedSubjectService : ICreditedSubjectService
{
    private readonly AppDbContext _context;

    public CreditedSubjectService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<List<CreditedSubjectDto>> GetByStudentAsync(Guid userId)
    {
        var credits = await _context.CreditedSubjects
            .AsNoTracking()
            .Include(c => c.Subject)
            .Include(c => c.Term)
            .Where(c => c.UserID == userId)
            .ToListAsync();

        var result = new List<CreditedSubjectDto>();
        foreach (var c in credits.OrderBy(c => c.Subject?.YearLevel).ThenBy(c => c.Subject?.SubjectCode))
        {
            result.Add(await MapAsync(c, c.Subject));
        }
        return result;
    }

    public async Task<CreditedSubjectDto> CreateAsync(CreateCreditedSubjectDto dto, Guid recordedByUserId)
    {
        var (credit, subject) = await BuildAsync(dto, recordedByUserId);
        _context.CreditedSubjects.Add(credit);
        await _context.SaveChangesAsync();

        return await MapAsync(credit, subject);
    }

    /// <summary>
    /// Checks a credit the same way for the dialog and the Excel import, and returns it without saving.
    /// Throws <see cref="KeyNotFoundException"/> or <see cref="InvalidOperationException"/> with a message for the Registrar.
    /// </summary>
    public async Task<(CreditedSubject Credit, Subject Subject)> BuildAsync(CreateCreditedSubjectDto dto, Guid recordedByUserId)
    {
        var (school, subject, term) = await CheckAsync(dto, editing: null);

        var credit = new CreditedSubject
        {
            CreditedSubjectID = Guid.NewGuid(),
            UserID = dto.UserId,
            SubjectID = dto.SubjectId,
            SourceSchool = school,
            SourceSubjectCode = Blank(dto.SourceSubjectCode),
            Grade = Blank(dto.Grade),
            // A cross-enrollment's school year is the DBTC term's.
            SchoolYear = term?.SchoolYear ?? Blank(dto.SchoolYear),
            CreditedUnits = dto.CreditedUnits,
            Kind = dto.Kind,
            TermID = term?.TermID,
            RecordedByUserID = recordedByUserId,
            RecordedAt = DateTime.UtcNow
        };
        return (credit, subject);
    }

    /// <summary>
    /// Corrects a credit already recorded. Everything the Registrar entered can be changed and is
    /// checked the way it was when the credit was recorded, so a correction cannot leave the record in
    /// a state the dialog would have refused. The student it belongs to, and who recorded it when, stay
    /// as they are: a credit put on the wrong student is removed and recorded on the right one.
    /// </summary>
    public async Task<CreditedSubjectDto> UpdateAsync(Guid creditedSubjectId, UpdateCreditedSubjectDto dto)
    {
        // Loaded without its subject and term: only the keys are written, and the checked subject and
        // term are mapped straight into the result, so no stale navigation is attached to the context.
        var credit = await _context.CreditedSubjects
            .FirstOrDefaultAsync(c => c.CreditedSubjectID == creditedSubjectId)
            ?? throw new KeyNotFoundException("Credited subject not found.");

        var asRecorded = new CreateCreditedSubjectDto
        {
            UserId = credit.UserID,
            SubjectId = dto.SubjectId,
            SourceSchool = dto.SourceSchool,
            SourceSubjectCode = dto.SourceSubjectCode,
            Grade = dto.Grade,
            SchoolYear = dto.SchoolYear,
            CreditedUnits = dto.CreditedUnits,
            Kind = dto.Kind,
            TermId = dto.TermId
        };
        var (school, subject, term) = await CheckAsync(asRecorded, editing: credit);

        credit.SubjectID = subject.SubjectID;
        credit.SourceSchool = school;
        credit.SourceSubjectCode = Blank(dto.SourceSubjectCode);
        credit.Grade = Blank(dto.Grade);
        credit.SchoolYear = term?.SchoolYear ?? Blank(dto.SchoolYear);
        credit.CreditedUnits = dto.CreditedUnits;
        credit.Kind = dto.Kind;
        credit.TermID = term?.TermID;
        await _context.SaveChangesAsync();

        return await MapAsync(credit, subject);
    }

    /// <summary>
    /// The checks shared by recording a credit and correcting one, returning the values to save.
    /// <paramref name="editing"/> is the credit being corrected, when there is one: it is left out of
    /// the "already credited" check, and the checks against the student's program and their DBTC
    /// coursework are made only for a subject the credit is being moved to. A correction to the details
    /// of a credit already recorded is therefore never trapped by something that changed since — a
    /// program shift, or a DBTC load opened in the meantime.
    /// </summary>
    private async Task<(string School, Subject Subject, AcademicTerm? Term)> CheckAsync(
        CreateCreditedSubjectDto dto, CreditedSubject? editing)
    {
        string school = await ResolveSchoolAsync(dto.SourceSchool);
        var movingToAnotherSubject = editing == null || editing.SubjectID != dto.SubjectId;

        var student = await _context.UserDetails
            .AsNoTracking()
            .Include(ud => ud.User)
            .FirstOrDefaultAsync(ud => ud.UserID == dto.UserId);
        if (student == null || student.User?.Role != RoleUtils.Student)
        {
            throw new KeyNotFoundException("Student not found.");
        }

        var subject = await _context.Subjects.AsNoTracking().FirstOrDefaultAsync(s => s.SubjectID == dto.SubjectId)
            ?? throw new KeyNotFoundException("Subject not found.");

        if (movingToAnotherSubject)
        {
            if (!student.ProgramID.HasValue)
            {
                throw new InvalidOperationException("Set the student's program before crediting subjects.");
            }
            if (subject.ProgramID != student.ProgramID.Value)
            {
                throw new InvalidOperationException($"{subject.SubjectCode} is not in the student's program curriculum.");
            }
        }

        var subjectUnits = subject.LecUnits + subject.LabUnits;
        if (dto.CreditedUnits <= 0)
        {
            throw new InvalidOperationException("Enter the units to credit (more than 0).");
        }
        if (dto.CreditedUnits > subjectUnits)
        {
            throw new InvalidOperationException($"{subject.SubjectCode} has only {subjectUnits:0.#} units; credit {subjectUnits:0.#} or fewer.");
        }
        if (dto.Kind is not (CreditKinds.Transfer or CreditKinds.CrossEnrollment))
        {
            throw new InvalidOperationException("Choose whether the subject was taken before DBTC or cross-enrolled.");
        }
        AcademicTerm? term = null;
        if (dto.Kind == CreditKinds.CrossEnrollment)
        {
            if (dto.TermId == null)
            {
                throw new InvalidOperationException("Choose the DBTC term the subject was cross-enrolled in.");
            }
            term = await _context.AcademicTerms.AsNoTracking().FirstOrDefaultAsync(t => t.TermID == dto.TermId)
                ?? throw new KeyNotFoundException("Term not found.");
        }

        var editingId = editing?.CreditedSubjectID;
        if (await _context.CreditedSubjects.AnyAsync(c =>
                c.UserID == dto.UserId && c.SubjectID == dto.SubjectId && c.CreditedSubjectID != editingId))
        {
            throw new InvalidOperationException($"{subject.SubjectCode} is already credited to this student.");
        }

        if (!movingToAnotherSubject)
        {
            return (school, subject, term);
        }

        // A DBTC pass, or a DBTC load still in progress, takes precedence over a credit.
        // A subject failed at DBTC may still be credited (e.g. passed elsewhere in summer).
        var dbtcLoads = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.UserID == dto.UserId && sl.Class != null && sl.Class.SubjectID == dto.SubjectId &&
                         (sl.LoadStatus == StudyLoadStatus.Enrolled || sl.LoadStatus == StudyLoadStatus.Pending))
            .Select(sl => new { sl.StudyLoadID, sl.LoadStatus })
            .ToListAsync();
        var loadIds = dbtcLoads.Select(l => l.StudyLoadID).ToList();
        var remarks = await _context.Grades
            .AsNoTracking()
            .Where(g => loadIds.Contains(g.StudyLoadID))
            .ToDictionaryAsync(g => g.StudyLoadID, g => g.Remarks);

        if (dbtcLoads.Any(l => l.LoadStatus == StudyLoadStatus.Enrolled && remarks.GetValueOrDefault(l.StudyLoadID) == 1))
        {
            throw new InvalidOperationException($"The student already passed {subject.SubjectCode} at DBTC.");
        }
        if (dbtcLoads.Any(l => l.LoadStatus == StudyLoadStatus.Pending ||
                               remarks.GetValueOrDefault(l.StudyLoadID) is not (1 or 2)))
        {
            throw new InvalidOperationException(
                $"The student is currently taking {subject.SubjectCode} at DBTC (pending or not yet graded). Drop or reject that load before crediting it.");
        }

        return (school, subject, term);
    }

    /// <summary>
    /// Trims the typed school name and, when it is a school already on the accredited list typed
    /// differently, swaps in the list's spelling so every record spells the school the same way.
    /// </summary>
    private async Task<string> ResolveSchoolAsync(string? typed)
    {
        var school = AccreditedSchoolService.Normalize(typed ?? string.Empty);
        if (school.Length == 0)
        {
            throw new InvalidOperationException("Enter the name of the school where the subject was taken.");
        }
        var listed = await _context.AccreditedSchools.AsNoTracking().Select(s => s.Name).ToListAsync();
        return listed.FirstOrDefault(n => string.Equals(AccreditedSchoolService.Normalize(n), school, StringComparison.OrdinalIgnoreCase)) ?? school;
    }

    public async Task<CreditedSubjectDto?> GetByIdAsync(Guid creditedSubjectId)
    {
        var c = await _context.CreditedSubjects.AsNoTracking().Include(x => x.Subject).Include(x => x.Term)
            .FirstOrDefaultAsync(x => x.CreditedSubjectID == creditedSubjectId);
        return c == null ? null : await MapAsync(c, c.Subject);
    }

    public async Task DeleteAsync(Guid creditedSubjectId)
    {
        var credit = await _context.CreditedSubjects.FirstOrDefaultAsync(c => c.CreditedSubjectID == creditedSubjectId)
            ?? throw new KeyNotFoundException("Credited subject not found.");
        _context.CreditedSubjects.Remove(credit);
        await _context.SaveChangesAsync();
    }

    private static string? Blank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

    private async Task<CreditedSubjectDto> MapAsync(CreditedSubject c, Subject? subject)
    {
        var term = c.Term ?? (c.TermID.HasValue
            ? await _context.AcademicTerms.AsNoTracking().FirstOrDefaultAsync(t => t.TermID == c.TermID)
            : null);
        var recorder = await _context.UserDetails.AsNoTracking().FirstOrDefaultAsync(u => u.UserID == c.RecordedByUserID);
        return new CreditedSubjectDto
        {
            CreditedSubjectId = c.CreditedSubjectID,
            UserId = c.UserID,
            SubjectId = c.SubjectID,
            SubjectCode = subject?.SubjectCode ?? string.Empty,
            SubjectTitle = subject?.SubjectTitle ?? string.Empty,
            Units = (subject?.LecUnits ?? 0) + (subject?.LabUnits ?? 0),
            YearLevel = subject?.YearLevel ?? 0,
            SourceSchool = c.SourceSchool,
            SourceSubjectCode = c.SourceSubjectCode,
            Grade = c.Grade,
            SchoolYear = c.SchoolYear,
            RecordedBy = recorder != null ? $"{recorder.Firstname} {recorder.Lastname}".Trim() : null,
            RecordedAt = c.RecordedAt,
            CreditedUnits = c.CreditedUnits,
            IsPartial = c.CreditedUnits < (subject?.LecUnits ?? 0) + (subject?.LabUnits ?? 0),
            Kind = c.Kind,
            TermId = c.TermID,
            TermLabel = term != null ? TermLabel.Format(term.SchoolYear, term.Semester) : null
        };
    }
}
