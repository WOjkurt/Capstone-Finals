using Api.Domain.Enrollment;
using Api.DTOs.Reports;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface IReportService
{
    Task<List<EnrollmentSummaryRowDto>> GetEnrollmentSummaryAsync(Guid termId);
    Task<List<ClassSizeRowDto>> GetClassSizesAsync(Guid termId);
    Task<List<FailedStudentRowDto>> GetFailedStudentsAsync(Guid termId);
    Task<List<TeacherLoadRowDto>> GetTeacherLoadsAsync(Guid termId);
}

/// <summary>Read-only term reports for the Registrar. Rejected, dropped and withdrawn loads are not counted.</summary>
public class ReportService : IReportService
{
    private readonly AppDbContext _context;

    public ReportService(AppDbContext context)
    {
        _context = context;
    }

    private async Task EnsureTermAsync(Guid termId)
    {
        if (!await _context.AcademicTerms.AnyAsync(t => t.TermID == termId))
        {
            throw new KeyNotFoundException($"AcademicTerm with ID '{termId}' was not found.");
        }
    }

    /// <summary>Enrolled and Pending loads of the term with their class and subject.</summary>
    private Task<List<StudyLoad>> ActiveLoadsAsync(Guid termId) =>
        _context.StudyLoads
            .AsNoTracking()
            .Include(sl => sl.Class)
                .ThenInclude(c => c!.Subject)
                    .ThenInclude(s => s!.Program)
            .Where(sl => sl.Class != null && sl.Class.TermID == termId &&
                         (sl.LoadStatus == StudyLoadStatus.Enrolled || sl.LoadStatus == StudyLoadStatus.Pending))
            .ToListAsync();

    private async Task<Dictionary<Guid, string>> NamesAsync(IEnumerable<Guid> userIds)
    {
        var ids = userIds.Distinct().ToList();
        return await _context.UserDetails
            .AsNoTracking()
            .Where(u => ids.Contains(u.UserID))
            .ToDictionaryAsync(u => u.UserID, u => $"{u.Firstname} {u.Lastname}".Trim());
    }

    public async Task<List<EnrollmentSummaryRowDto>> GetEnrollmentSummaryAsync(Guid termId)
    {
        await EnsureTermAsync(termId);
        var loads = await ActiveLoadsAsync(termId);
        var userIds = loads.Select(l => l.UserID).Distinct().ToList();
        var students = await _context.UserDetails
            .AsNoTracking()
            .Include(u => u.Program)
            .Where(u => userIds.Contains(u.UserID))
            .ToDictionaryAsync(u => u.UserID);

        return loads
            .GroupBy(l => l.UserID)
            .Select(g =>
            {
                students.TryGetValue(g.Key, out var ud);
                return new
                {
                    Program = ud?.Program?.ProgramCode ?? "No program",
                    Year = ud?.YearLevel,
                    Enrolled = g.Any(l => l.LoadStatus == StudyLoadStatus.Enrolled)
                };
            })
            .GroupBy(s => (s.Program, s.Year))
            .Select(g => new EnrollmentSummaryRowDto
            {
                ProgramCode = g.Key.Program,
                YearLevel = g.Key.Year,
                EnrolledStudents = g.Count(s => s.Enrolled),
                PendingOnlyStudents = g.Count(s => !s.Enrolled)
            })
            .OrderBy(r => r.ProgramCode).ThenBy(r => r.YearLevel)
            .ToList();
    }

    public async Task<List<ClassSizeRowDto>> GetClassSizesAsync(Guid termId)
    {
        await EnsureTermAsync(termId);
        var classes = await _context.Classes
            .AsNoTracking()
            .Include(c => c.Subject)
                .ThenInclude(s => s!.Program)
            .Where(c => c.TermID == termId)
            .ToListAsync();
        var loads = await ActiveLoadsAsync(termId);
        var byClass = loads.ToLookup(l => l.ClassID);
        var names = await NamesAsync(classes.Where(c => c.UserID.HasValue).Select(c => c.UserID!.Value));

        return classes
            .Select(c => new ClassSizeRowDto
            {
                ClassId = c.ClassID,
                ClassName = c.ClassName,
                SubjectCode = c.Subject?.SubjectCode ?? string.Empty,
                SubjectTitle = c.Subject?.SubjectTitle ?? string.Empty,
                ProgramCode = c.Subject?.Program?.ProgramCode ?? string.Empty,
                TeacherName = c.UserID.HasValue ? names.GetValueOrDefault(c.UserID.Value) : null,
                Enrolled = byClass[c.ClassID].Count(l => l.LoadStatus == StudyLoadStatus.Enrolled),
                Pending = byClass[c.ClassID].Count(l => l.LoadStatus == StudyLoadStatus.Pending)
            })
            .OrderBy(r => r.ProgramCode).ThenBy(r => r.ClassName).ThenBy(r => r.SubjectCode)
            .ToList();
    }

    public async Task<List<FailedStudentRowDto>> GetFailedStudentsAsync(Guid termId)
    {
        await EnsureTermAsync(termId);
        var failed = await _context.Grades
            .AsNoTracking()
            .Include(g => g.StudyLoad)
                .ThenInclude(sl => sl!.Class)
                    .ThenInclude(c => c!.Subject)
            .Where(g => g.Remarks == 2 && g.StudyLoad != null && g.StudyLoad.LoadStatus == StudyLoadStatus.Enrolled &&
                        g.StudyLoad.Class != null && g.StudyLoad.Class.TermID == termId)
            .ToListAsync();

        var studentIds = failed.Select(g => g.StudyLoad!.UserID).Distinct().ToList();
        var students = await _context.UserDetails
            .AsNoTracking()
            .Include(u => u.Program)
            .Where(u => studentIds.Contains(u.UserID))
            .ToDictionaryAsync(u => u.UserID);
        var teachers = await NamesAsync(failed.Where(g => g.StudyLoad!.Class!.UserID.HasValue).Select(g => g.StudyLoad!.Class!.UserID!.Value));

        return failed
            .Select(g =>
            {
                var load = g.StudyLoad!;
                students.TryGetValue(load.UserID, out var ud);
                return new FailedStudentRowDto
                {
                    UserId = load.UserID,
                    StudentName = ud != null ? $"{ud.Firstname} {ud.Lastname}".Trim() : "Unknown",
                    Lrn = ud?.LRN,
                    ProgramCode = ud?.Program?.ProgramCode,
                    YearLevel = ud?.YearLevel,
                    SubjectCode = load.Class!.Subject?.SubjectCode ?? string.Empty,
                    SubjectTitle = load.Class.Subject?.SubjectTitle ?? string.Empty,
                    ClassName = load.Class.ClassName,
                    FinalGrade = g.FinalGrade,
                    TeacherName = load.Class.UserID.HasValue ? teachers.GetValueOrDefault(load.Class.UserID.Value) : null
                };
            })
            .OrderBy(r => r.ProgramCode).ThenBy(r => r.YearLevel).ThenBy(r => r.StudentName).ThenBy(r => r.SubjectCode)
            .ToList();
    }

    public async Task<List<TeacherLoadRowDto>> GetTeacherLoadsAsync(Guid termId)
    {
        await EnsureTermAsync(termId);
        var classes = await _context.Classes
            .AsNoTracking()
            .Include(c => c.Subject)
            .Where(c => c.TermID == termId)
            .ToListAsync();
        var enrolledByClass = (await ActiveLoadsAsync(termId))
            .Where(l => l.LoadStatus == StudyLoadStatus.Enrolled)
            .GroupBy(l => l.ClassID)
            .ToDictionary(g => g.Key, g => g.Count());
        var names = await NamesAsync(classes.Where(c => c.UserID.HasValue).Select(c => c.UserID!.Value));

        return classes
            .GroupBy(c => c.UserID)
            .Select(g => new TeacherLoadRowDto
            {
                TeacherUserId = g.Key,
                TeacherName = g.Key.HasValue ? names.GetValueOrDefault(g.Key.Value) ?? "Unknown" : "Unassigned",
                Classes = g.Count(),
                Units = g.Sum(c => (c.Subject?.LecUnits ?? 0) + (c.Subject?.LabUnits ?? 0)),
                Students = g.Sum(c => enrolledByClass.GetValueOrDefault(c.ClassID)),
                SubjectCodes = g.Select(c => c.Subject?.SubjectCode ?? "?").Distinct().OrderBy(x => x).ToList()
            })
            // Unassigned last, then teachers by name.
            .OrderBy(r => r.TeacherUserId == null).ThenBy(r => r.TeacherName)
            .ToList();
    }
}
