using Api.Common;
using Api.Domain.Enrollment;
using Api.DTOs.Reports;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface IReportService
{
    Task<List<EnrollmentSummaryRowDto>> GetEnrollmentSummaryAsync(Guid termId);
    Task<List<ClassSizeRowDto>> GetClassSizesAsync(Guid termId);
    Task<List<FailedStudentRowDto>> GetFailedStudentsAsync(Guid termId);
    Task<DeansListDto> GetDeansListAsync(Guid termId, decimal maxGwa, decimal minUnits, decimal worstGrade);
    Task<List<TeacherLoadRowDto>> GetTeacherLoadsAsync(Guid termId);
    Task<List<TransfereeRowDto>> GetTransfereesAsync();
    Task<List<EnrollmentStatisticsRowDto>> GetEnrollmentStatisticsAsync(Guid termId);
    Task<List<ClassListDto>> GetClassListsAsync(Guid termId, Guid? classId);
    Task<List<MissingSexRowDto>> GetStudentsMissingSexAsync(Guid termId);
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

    /// <summary>
    /// Students whose term GWA is at most <paramref name="maxGwa"/>, who carried at least <paramref name="minUnits"/> units,
    /// and whose every grade is <paramref name="worstGrade"/> or better. A failed, dropped or withdrawn subject leaves a
    /// student out; so does a subject without a final grade yet (counted separately, since the list isn't final then).
    /// </summary>
    public async Task<DeansListDto> GetDeansListAsync(Guid termId, decimal maxGwa, decimal minUnits, decimal worstGrade)
    {
        await EnsureTermAsync(termId);
        var loads = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.Class != null && sl.Class.TermID == termId &&
                         (sl.LoadStatus == StudyLoadStatus.Enrolled || sl.LoadStatus == StudyLoadStatus.Dropped || sl.LoadStatus == StudyLoadStatus.Withdrawn))
            .Select(sl => new
            {
                sl.UserID, sl.LoadStatus, sl.Class!.Subject!.SubjectCode, Units = sl.Class.Subject.LecUnits + sl.Class.Subject.LabUnits,
                Final = _context.Grades.Where(g => g.StudyLoadID == sl.StudyLoadID).Select(g => g.FinalGrade).FirstOrDefault(),
            })
            .ToListAsync();

        var result = new DeansListDto { MaxGwa = maxGwa, MinUnits = minUnits, WorstGrade = worstGrade };
        var qualified = new List<DeansListRowDto>();
        foreach (var student in loads.GroupBy(l => l.UserID))
        {
            var enrolled = student.Where(l => l.LoadStatus == StudyLoadStatus.Enrolled).ToList();
            if (enrolled.Any(l => l.Final == null))
            {
                result.StudentsWithMissingGrades++;
                continue;
            }
            result.StudentsChecked++;
            if (student.Any(l => l.LoadStatus != StudyLoadStatus.Enrolled)) continue;   // dropped or withdrawn
            decimal units = enrolled.Sum(l => l.Units);
            // DBTC counts every subject in the Dean's list GWA, NSTP and PE included.
            var counted = enrolled.Where(l => l.Units > 0).ToList();
            decimal countedUnits = counted.Sum(l => l.Units);
            if (units < minUnits || countedUnits == 0) continue;
            decimal lowest = enrolled.Max(l => l.Final!.Value);
            if (lowest > worstGrade || lowest > GradeScale.PassingMax) continue;
            decimal gwa = Math.Round(counted.Sum(l => l.Units * l.Final!.Value) / countedUnits, 4);
            if (gwa > maxGwa) continue;
            qualified.Add(new DeansListRowDto { UserId = student.Key, Units = units, Gwa = gwa, LowestGrade = lowest });
        }

        var ids = qualified.Select(q => q.UserId).ToList();
        var details = await _context.UserDetails.AsNoTracking().Include(u => u.Program)
            .Where(u => ids.Contains(u.UserID)).ToDictionaryAsync(u => u.UserID);
        foreach (var q in qualified)
        {
            if (!details.TryGetValue(q.UserId, out var ud)) continue;
            q.StudentName = $"{ud.Lastname}, {ud.Firstname}";
            q.StudentId = ud.StudentID;
            q.ProgramCode = ud.Program?.ProgramCode;
            q.YearLevel = ud.YearLevel;
        }
        result.Rows = qualified
            .OrderBy(q => Math.Round(q.Gwa, 2)).ThenBy(q => q.StudentName, StringComparer.OrdinalIgnoreCase)
            .ToList();
        // Equal GWAs (to two decimals) share a rank: 1, 2, 2, 4.
        for (int i = 0; i < result.Rows.Count; i++)
        {
            result.Rows[i].Rank = i > 0 && Math.Round(result.Rows[i].Gwa, 2) == Math.Round(result.Rows[i - 1].Gwa, 2)
                ? result.Rows[i - 1].Rank : i + 1;
        }
        return result;
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

    /// <summary>
    /// Students marked as transferees on their record, plus anyone with credits from another school.
    /// Not tied to a term. Sorted by program, year level and name.
    /// </summary>
    public async Task<List<TransfereeRowDto>> GetTransfereesAsync()
    {
        // Cross-enrolled subjects are not transfers; they are left out here.
        var credits = await _context.CreditedSubjects
            .AsNoTracking()
            .Where(c => c.Subject != null && c.Kind == CreditKinds.Transfer)
            .Select(c => new { c.UserID, c.SourceSchool, c.Subject!.SubjectCode, Units = c.CreditedUnits })
            .ToListAsync();
        var creditedIds = credits.Select(c => c.UserID).Distinct().ToList();

        var students = await _context.UserDetails
            .AsNoTracking()
            .Include(u => u.Program)
            .Where(u => u.User != null && u.User.Role == Api.Auth.RoleUtils.Student &&
                        (u.StudentType == 3 || creditedIds.Contains(u.UserID)))
            .ToListAsync();
        var ids = students.Select(s => s.UserID).ToList();
        var previousCollege = (await _context.EnrollmentForms
                .AsNoTracking()
                .Where(f => f.Application != null && f.Application.StudentUserID != null && ids.Contains(f.Application.StudentUserID.Value))
                .Select(f => new { UserID = f.Application!.StudentUserID!.Value, f.PreviousCollege, f.Application.CreatedAt })
                .ToListAsync())
            .GroupBy(f => f.UserID)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(f => f.CreatedAt).First().PreviousCollege);
        var creditsBy = credits.ToLookup(c => c.UserID);

        static bool Meaningful(string? s) =>
            !string.IsNullOrWhiteSpace(s) && !new[] { "N/A", "NA", "NONE", "-" }.Contains(s.Trim().ToUpperInvariant());

        return students
            .Select(s =>
            {
                var mine = creditsBy[s.UserID].ToList();
                var schools = mine.Select(c => c.SourceSchool.Trim()).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(n => n).ToList();
                if (schools.Count == 0 && previousCollege.TryGetValue(s.UserID, out var prev) && Meaningful(prev))
                {
                    schools.Add(prev.Trim());
                }
                return new TransfereeRowDto
                {
                    UserId = s.UserID,
                    StudentName = $"{s.Firstname} {s.Lastname}".Trim(),
                    Lrn = s.LRN,
                    ProgramCode = s.Program?.ProgramCode,
                    YearLevel = s.YearLevel,
                    PreviousSchools = schools,
                    CreditedSubjects = mine.Count,
                    CreditedUnits = mine.Sum(c => c.Units),
                    CreditedCodes = mine.Select(c => c.SubjectCode).OrderBy(c => c).ToList()
                };
            })
            .OrderBy(r => r.ProgramCode).ThenBy(r => r.YearLevel).ThenBy(r => r.StudentName)
            .ToList();
    }

    /// <summary>
    /// Officially enrolled students (at least one Enrolled subject in the term) per program, by year level and sex.
    /// Sex comes from the Registrar's personal details, else the latest enrollment form. Every program is listed.
    /// </summary>
    public async Task<List<EnrollmentStatisticsRowDto>> GetEnrollmentStatisticsAsync(Guid termId)
    {
        await EnsureTermAsync(termId);
        var enrolledIds = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.LoadStatus == StudyLoadStatus.Enrolled && sl.Class != null && sl.Class.TermID == termId)
            .Select(sl => sl.UserID)
            .Distinct()
            .ToListAsync();
        var students = await _context.UserDetails
            .AsNoTracking()
            .Where(u => enrolledIds.Contains(u.UserID))
            .Select(u => new { u.UserID, u.ProgramID, u.YearLevel })
            .ToListAsync();
        var sexes = await SexesAsync(enrolledIds);

        var programs = await _context.AcademicPrograms.AsNoTracking().OrderBy(p => p.ProgramCode).ToListAsync();
        var rows = programs.ToDictionary(p => p.ProgramID, p => new EnrollmentStatisticsRowDto { ProgramCode = p.ProgramCode, ProgramName = p.FullName });
        foreach (var st in students)
        {
            if (st.ProgramID is not int pid || !rows.TryGetValue(pid, out var row)) continue;
            var sex = sexes.GetValueOrDefault(st.UserID);
            if (st.YearLevel is not int year || year < 1)
            {
                row.YearNotRecorded++;
                continue;
            }
            var i = Math.Min(year, 4) - 1;
            if (sex == 'M') row.Male[i]++;
            else if (sex == 'F') row.Female[i]++;
            else row.SexNotRecorded++;
        }
        return rows.Values.ToList();
    }

    /// <summary>
    /// 'M' or 'F' per student: the Registrar's personal details first, else the latest enrollment form.
    /// Students with nothing usable are left out.
    /// </summary>
    private async Task<Dictionary<Guid, char>> SexesAsync(List<Guid> userIds)
    {
        var saved = await _context.StudentPersonalDetails
            .AsNoTracking()
            .Where(d => userIds.Contains(d.UserID) && d.Sex != null)
            .ToDictionaryAsync(d => d.UserID, d => d.Sex);
        var fromForm = (await _context.EnrollmentForms
                .AsNoTracking()
                .Where(f => f.Application != null && f.Application.StudentUserID != null && userIds.Contains(f.Application.StudentUserID.Value))
                .Select(f => new { UserID = f.Application!.StudentUserID!.Value, f.Sex, f.Application.CreatedAt })
                .ToListAsync())
            .GroupBy(f => f.UserID)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(f => f.CreatedAt).First().Sex);

        var result = new Dictionary<Guid, char>();
        foreach (var id in userIds)
        {
            var v = (saved.GetValueOrDefault(id) ?? fromForm.GetValueOrDefault(id))?.Trim().ToUpperInvariant();
            if (!string.IsNullOrEmpty(v) && v[0] is 'M' or 'F') result[id] = v[0];
        }
        return result;
    }

    /// <summary>
    /// Printable class lists for a term (or one class): header details and the Enrolled students,
    /// sorted by last name. Classes are sorted by subject code and section.
    /// </summary>
    public async Task<List<ClassListDto>> GetClassListsAsync(Guid termId, Guid? classId)
    {
        var term = await _context.AcademicTerms.AsNoTracking().FirstOrDefaultAsync(t => t.TermID == termId)
            ?? throw new KeyNotFoundException($"AcademicTerm with ID '{termId}' was not found.");
        var classes = await _context.Classes
            .AsNoTracking()
            .Include(c => c.Subject)
            .Include(c => c.ClassSchedules)
            .Where(c => c.TermID == termId && (classId == null || c.ClassID == classId))
            .ToListAsync();
        if (classId != null && classes.Count == 0)
        {
            throw new KeyNotFoundException("Class not found in this term.");
        }
        var classIds = classes.Select(c => c.ClassID).ToList();
        var loads = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => classIds.Contains(sl.ClassID) && sl.LoadStatus == StudyLoadStatus.Enrolled)
            .Select(sl => new { sl.ClassID, sl.UserID })
            .ToListAsync();
        var studentIds = loads.Select(l => l.UserID).Distinct().ToList();
        var students = await _context.UserDetails
            .AsNoTracking()
            .Include(u => u.Program)
            .Where(u => studentIds.Contains(u.UserID))
            .ToDictionaryAsync(u => u.UserID);
        var sexes = await SexesAsync(studentIds);
        var teachers = await NamesAsync(classes.Where(c => c.UserID.HasValue).Select(c => c.UserID!.Value));
        var byClass = loads.ToLookup(l => l.ClassID, l => l.UserID);

        static string Time(TimeOnly t) => t.ToString("h:mm tt", System.Globalization.CultureInfo.InvariantCulture);

        return classes
            .OrderBy(c => c.Subject?.SubjectCode).ThenBy(c => c.ClassName)
            .Select(c => new ClassListDto
            {
                ClassId = c.ClassID,
                ClassName = c.ClassName,
                SubjectCode = c.Subject?.SubjectCode ?? string.Empty,
                SubjectTitle = c.Subject?.SubjectTitle ?? string.Empty,
                Units = (c.Subject?.LecUnits ?? 0) + (c.Subject?.LabUnits ?? 0),
                TermLabel = Api.Common.TermLabel.Format(term.SchoolYear, term.Semester),
                TeacherName = c.UserID.HasValue ? teachers.GetValueOrDefault(c.UserID.Value) : null,
                Schedules = c.ClassSchedules
                    .OrderBy(s => s.StartTime)
                    .Select(s => $"{s.DaysOfWeek} {Time(s.StartTime)} - {Time(s.EndTime)}{(string.IsNullOrWhiteSpace(s.Room) ? "" : $" · {s.Room.Trim()}")}")
                    .ToList(),
                Students = byClass[c.ClassID]
                    .Distinct()
                    .Select(id =>
                    {
                        students.TryGetValue(id, out var u);
                        return new ClassListStudentDto
                        {
                            UserId = id,
                            Name = u == null ? "Unknown student" : $"{u.Lastname.Trim().ToUpperInvariant()}, {u.Firstname.Trim()}",
                            Lrn = u?.LRN,
                            ProgramCode = u?.Program?.ProgramCode,
                            YearLevel = u?.YearLevel,
                            Sex = sexes.TryGetValue(id, out var sx) ? sx.ToString() : null
                        };
                    })
                    .OrderBy(st => st.Name, StringComparer.OrdinalIgnoreCase)
                    .ToList()
            })
            .ToList();
    }

    /// <summary>Enrolled students of the term with no sex on record (not in the statistics or class list counts).</summary>
    public async Task<List<MissingSexRowDto>> GetStudentsMissingSexAsync(Guid termId)
    {
        await EnsureTermAsync(termId);
        var enrolledIds = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.LoadStatus == StudyLoadStatus.Enrolled && sl.Class != null && sl.Class.TermID == termId)
            .Select(sl => sl.UserID)
            .Distinct()
            .ToListAsync();
        var known = await SexesAsync(enrolledIds);
        var missing = enrolledIds.Where(id => !known.ContainsKey(id)).ToList();
        return (await _context.UserDetails
                .AsNoTracking()
                .Include(u => u.Program)
                .Where(u => missing.Contains(u.UserID))
                .ToListAsync())
            .Select(u => new MissingSexRowDto
            {
                UserId = u.UserID,
                StudentName = $"{u.Lastname.Trim().ToUpperInvariant()}, {u.Firstname.Trim()}",
                Lrn = u.LRN,
                ProgramCode = u.Program?.ProgramCode,
                YearLevel = u.YearLevel
            })
            .OrderBy(r => r.StudentName, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
}
