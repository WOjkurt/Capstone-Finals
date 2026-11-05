using Api.Constants;
using Api.Auth;
using Api.Common;
using Api.Domain.Enrollment;
using Api.DTOs.Records;
using Microsoft.EntityFrameworkCore;
using static Api.Services.StudyLoadService;

namespace Api.Services;

public interface IStudentRecordService
{
    Task<StudentEvaluationDto> GetEvaluationAsync(Guid userId);
    Task<TranscriptDto> GetTranscriptAsync(Guid userId);
    Task<PersonalDetailsDto> GetPersonalDetailsAsync(Guid userId);
    Task<PersonalDetailsDto> UpdatePersonalDetailsAsync(Guid userId, UpdatePersonalDetailsDto dto, Guid updatedBy);
}

/// <summary>Read-only views of a student's academic record for the Registrar.</summary>
public class StudentRecordService : IStudentRecordService
{
    private readonly AppDbContext _context;

    public StudentRecordService(AppDbContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Every subject of the student's program curriculum with its status. Uses the same pass/fail rule as
    /// prerequisites and promotion, so the checklist always agrees with what the study load builder allows.
    /// </summary>
    public async Task<StudentEvaluationDto> GetEvaluationAsync(Guid userId)
    {
        var student = await _context.UserDetails
            .AsNoTracking()
            .Include(ud => ud.Program)
            .FirstOrDefaultAsync(ud => ud.UserID == userId && ud.User != null && ud.User.Role == RoleUtils.Student)
            ?? throw new KeyNotFoundException("Student not found.");
        if (student.ProgramID == null || student.Program == null)
        {
            throw new InvalidOperationException("This student has no program yet. Set their program first.");
        }

        var subjects = await _context.Subjects
            .AsNoTracking()
            .Where(s => s.ProgramID == student.ProgramID)
            .OrderBy(s => s.YearLevel).ThenBy(s => s.DefaultSemester).ThenBy(s => s.SubjectCode)
            .ToListAsync();
        var subjectIds = subjects.Select(s => s.SubjectID).ToList();

        var attempts = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.UserID == userId && sl.Class != null && subjectIds.Contains(sl.Class.SubjectID))
            .Select(sl => new
            {
                sl.StudyLoadID,
                SubjectID = sl.Class!.SubjectID,
                sl.LoadStatus,
                sl.Class.Term!.SchoolYear,
                sl.Class.Term.Semester
            })
            .ToListAsync();
        var loadIds = attempts.Select(a => a.StudyLoadID).ToList();
        var grades = await _context.Grades
            .AsNoTracking()
            .Where(g => loadIds.Contains(g.StudyLoadID))
            .ToDictionaryAsync(g => g.StudyLoadID, g => new { g.Remarks, g.FinalGrade });
        var credits = (await _context.CreditedSubjects
                .AsNoTracking()
                .Where(c => c.UserID == userId)
                .ToListAsync())
            .GroupBy(c => c.SubjectID)
            .ToDictionary(g => g.Key, g => g.First());
        var attemptsBy = attempts.ToLookup(a => a.SubjectID);
        var requisites = (await _context.SubjectPrerequisites
                .AsNoTracking()
                .Where(sp => subjectIds.Contains(sp.SubjectID) && sp.PrerequisiteSubject != null)
                .Select(sp => new { sp.SubjectID, sp.RequisiteType, sp.PrerequisiteSubject!.SubjectCode })
                .ToListAsync())
            .ToLookup(r => (r.SubjectID, r.RequisiteType), r => r.SubjectCode);
        string? Join(IEnumerable<string> parts)
        {
            var list = parts.ToList();
            return list.Count == 0 ? null : string.Join(", ", list);
        }

        var result = new StudentEvaluationDto
        {
            UserId = userId,
            FullName = $"{student.Firstname} {student.Lastname}".Trim(),
            Lrn = student.LRN,
            ProgramCode = student.Program.ProgramCode,
            ProgramName = student.Program.ProgramName,
            YearLevel = student.YearLevel
        };

        foreach (var subject in subjects)
        {
            var units = subject.LecUnits + subject.LabUnits;
            var row = new EvaluationSubjectDto
            {
                SubjectId = subject.SubjectID,
                SubjectCode = subject.SubjectCode,
                SubjectTitle = subject.SubjectTitle,
                Units = units,
                LecHours = subject.LecHours,
                LabHours = subject.LabHours,
                Prerequisites = Join(requisites[(subject.SubjectID, RequisiteTypeConstants.Prerequisite)].OrderBy(c => c)
                    .Concat(subject.StandingYear is int y ? new[] { $"{Ordinal(y)} year standing" } : Array.Empty<string>())),
                Corequisites = Join(requisites[(subject.SubjectID, RequisiteTypeConstants.Corequisite)].OrderBy(c => c)),
                YearLevel = subject.YearLevel,
                Semester = subject.DefaultSemester,
                IsMinor = subject.IsMinor
            };

            // Newest first, so "the latest attempt" is the first match.
            var tries = attemptsBy[subject.SubjectID]
                .Select(a =>
                {
                    grades.TryGetValue(a.StudyLoadID, out var g);
                    return new { a.LoadStatus, a.SchoolYear, a.Semester, Remarks = g?.Remarks, FinalGrade = g?.FinalGrade };
                })
                .OrderByDescending(a => a.SchoolYear).ThenByDescending(a => a.Semester)
                .ToList();

            if (credits.TryGetValue(subject.SubjectID, out var credit))
            {
                row.Status = "Credited";
                row.CreditedFrom = credit.SourceSchool;
                row.CreditedGrade = credit.Grade;
                row.TermLabel = credit.SchoolYear;
            }
            else
            {
                var status = ClassifyAttempts(false, tries.Select(t => (t.LoadStatus, t.Remarks)));
                var enrolled = tries.Where(t => t.LoadStatus == StudyLoadStatus.Enrolled).ToList();
                var decider = status switch
                {
                    SubjectCompletionStatus.Passed => enrolled.Where(t => t.Remarks == 1).OrderBy(t => t.FinalGrade).FirstOrDefault(),
                    SubjectCompletionStatus.InProgress => enrolled.FirstOrDefault(t => t.Remarks is not (1 or 2)),
                    SubjectCompletionStatus.Failed => enrolled.FirstOrDefault(t => t.Remarks == 2),
                    SubjectCompletionStatus.DroppedOrWithdrawn => tries.FirstOrDefault(t =>
                        t.LoadStatus == StudyLoadStatus.Dropped || t.LoadStatus == StudyLoadStatus.Withdrawn),
                    _ => null
                };
                row.Status = status switch
                {
                    SubjectCompletionStatus.Passed => "Passed",
                    SubjectCompletionStatus.InProgress => "InProgress",
                    SubjectCompletionStatus.Failed => "Failed",
                    SubjectCompletionStatus.DroppedOrWithdrawn => "Dropped",
                    _ => "NotTaken"
                };
                if (decider != null)
                {
                    row.FinalGrade = decider.FinalGrade;
                    row.TermLabel = TermLabel.Format(decider.SchoolYear, decider.Semester);
                }
            }

            result.TotalUnits += units;
            if (row.Status is "Passed" or "Credited") result.EarnedUnits += units;
            if (row.Status == "InProgress") result.InProgressUnits += units;
            result.Subjects.Add(row);
        }

        result.RemainingUnits = result.TotalUnits - result.EarnedUnits;
        return result;
    }

    /// <summary>
    /// The Transcript of Records: every term with an Enrolled, Dropped or Withdrawn subject (oldest first),
    /// plus subjects credited from other schools. Pending and Rejected loads never appear.
    /// </summary>
    public async Task<TranscriptDto> GetTranscriptAsync(Guid userId)
    {
        var student = await _context.UserDetails
            .AsNoTracking()
            .Include(ud => ud.Program)
            .FirstOrDefaultAsync(ud => ud.UserID == userId && ud.User != null && ud.User.Role == RoleUtils.Student)
            ?? throw new KeyNotFoundException("Student not found.");

        var details = await GetPersonalDetailsAsync(userId);

        var loads = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.UserID == userId && sl.Class != null && sl.Class.Subject != null && sl.Class.Term != null &&
                         (sl.LoadStatus == StudyLoadStatus.Enrolled || sl.LoadStatus == StudyLoadStatus.Dropped ||
                          sl.LoadStatus == StudyLoadStatus.Withdrawn))
            .Select(sl => new
            {
                sl.StudyLoadID,
                sl.LoadStatus,
                sl.Class!.Subject!.SubjectCode,
                sl.Class.Subject.SubjectTitle,
                Units = sl.Class.Subject.LecUnits + sl.Class.Subject.LabUnits,
                sl.Class.Term!.SchoolYear,
                sl.Class.Term.Semester
            })
            .ToListAsync();
        var loadIds = loads.Select(l => l.StudyLoadID).ToList();
        var finals = await _context.Grades
            .AsNoTracking()
            .Where(g => loadIds.Contains(g.StudyLoadID))
            .ToDictionaryAsync(g => g.StudyLoadID, g => g.FinalGrade);

        var result = new TranscriptDto
        {
            UserId = userId,
            FullName = $"{details.Lastname.Trim().ToUpperInvariant()}, {string.Join(" ", new[] { details.Firstname, details.MiddleName, details.Suffix }.Select(p => p?.Trim()).Where(p => !string.IsNullOrEmpty(p)))}",
            Lrn = student.LRN,
            ProgramCode = student.Program?.ProgramCode ?? string.Empty,
            ProgramName = student.Program?.ProgramName ?? string.Empty,
            Address = details.Address,
            DateOfBirth = details.DateOfBirth,
            PlaceOfBirth = details.PlaceOfBirth,
            Sex = details.Sex,
            Nationality = details.Nationality,
            EntranceData = details.EntranceData,
            DateAdmitted = details.DateAdmitted ?? details.FirstTermEnrolled
        };

        foreach (var term in loads.GroupBy(l => (l.SchoolYear, l.Semester)).OrderBy(g => g.Key.SchoolYear).ThenBy(g => g.Key.Semester))
        {
            result.Terms.Add(new TranscriptTermDto
            {
                Heading = Heading(term.Key.SchoolYear, term.Key.Semester),
                Rows = term.OrderBy(l => l.SubjectCode).Select(l => new TranscriptRowDto
                {
                    SubjectCode = l.SubjectCode,
                    SubjectTitle = l.SubjectTitle,
                    Units = l.Units,
                    Final = l.LoadStatus switch
                    {
                        StudyLoadStatus.Dropped => "DO",
                        StudyLoadStatus.Withdrawn => "W",
                        _ => finals.TryGetValue(l.StudyLoadID, out var f) && f.HasValue ? f.Value.ToString("0.00") : string.Empty
                    }
                }).ToList()
            });
        }

        var credits = await _context.CreditedSubjects
            .AsNoTracking()
            .Where(c => c.UserID == userId && c.Subject != null)
            .Select(c => new { c.SourceSchool, c.Subject!.SubjectCode, c.Subject.SubjectTitle, Units = c.Subject.LecUnits + c.Subject.LabUnits, c.Grade })
            .ToListAsync();
        result.Credits = credits
            .GroupBy(c => c.SourceSchool.Trim())
            .OrderBy(g => g.Key)
            .Select(g => new TranscriptCreditGroupDto
            {
                SourceSchool = g.Key,
                Rows = g.OrderBy(c => c.SubjectCode).Select(c => new TranscriptRowDto
                {
                    SubjectCode = c.SubjectCode,
                    SubjectTitle = c.SubjectTitle,
                    Units = c.Units,
                    Final = c.Grade?.Trim() ?? string.Empty
                }).ToList()
            })
            .ToList();
        return result;
    }

    /// <summary>"1st Semester, 2025-2026" or "Summer, 2025-2026", as written on a transcript.</summary>
    private static string Heading(string schoolYear, int semester) => semester switch
    {
        1 => $"1st Semester, {schoolYear}",
        2 => $"2nd Semester, {schoolYear}",
        3 => $"Summer, {schoolYear}",
        _ => $"Semester {semester}, {schoolYear}"
    };

    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    /// <summary>The Registrar's saved details, with each empty field filled from the latest enrollment form.</summary>
    public async Task<PersonalDetailsDto> GetPersonalDetailsAsync(Guid userId)
    {
        var student = await _context.UserDetails
            .AsNoTracking()
            .FirstOrDefaultAsync(ud => ud.UserID == userId && ud.User != null && ud.User.Role == RoleUtils.Student)
            ?? throw new KeyNotFoundException("Student not found.");
        var saved = await _context.StudentPersonalDetails.AsNoTracking().FirstOrDefaultAsync(d => d.UserID == userId);
        var form = await _context.EnrollmentForms
            .AsNoTracking()
            .Where(f => f.Application != null && f.Application.StudentUserID == userId)
            .OrderByDescending(f => f.Application!.CreatedAt)
            .FirstOrDefaultAsync();
        var firstTerm = await _context.StudyLoads
            .AsNoTracking()
            .Where(sl => sl.UserID == userId && sl.Class != null && sl.Class.Term != null &&
                         (sl.LoadStatus == StudyLoadStatus.Enrolled || sl.LoadStatus == StudyLoadStatus.Dropped ||
                          sl.LoadStatus == StudyLoadStatus.Withdrawn))
            .Select(sl => new { sl.Class!.Term!.SchoolYear, sl.Class.Term.Semester })
            .OrderBy(t => t.SchoolYear).ThenBy(t => t.Semester)
            .FirstOrDefaultAsync();

        var dto = new PersonalDetailsDto
        {
            UserId = userId,
            Firstname = student.Firstname,
            Lastname = student.Lastname,
            FirstTermEnrolled = firstTerm == null ? null : Heading(firstTerm.SchoolYear, firstTerm.Semester),
            HasEnrollmentForm = form != null,
            UpdatedAt = saved?.UpdatedAt
        };
        if (saved != null)
        {
            dto.UpdatedBy = await _context.UserDetails.AsNoTracking()
                .Where(u => u.UserID == saved.UpdatedByUserID)
                .Select(u => u.Firstname + " " + u.Lastname)
                .FirstOrDefaultAsync();
        }

        string? Pick(string field, string? mine, string? fromForm)
        {
            if (Clean(mine) is { } v) return v;
            if (Clean(fromForm) is { } f)
            {
                dto.FromForm.Add(field);
                return f;
            }
            return null;
        }

        var formAddress = form == null ? null : string.Join(", ", new[] { form.HouseStreet, form.Barangay, form.CityMunicipality, form.Province }
            .Select(Clean).Where(p => p != null));
        dto.MiddleName = Pick("middleName", saved?.MiddleName, form?.MiddleName);
        dto.Suffix = Pick("suffix", saved?.Suffix, form?.Suffix);
        dto.Address = Pick("address", saved?.Address, formAddress);
        dto.PlaceOfBirth = Pick("placeOfBirth", saved?.PlaceOfBirth, form?.PlaceOfBirth);
        dto.Sex = Pick("sex", saved?.Sex, form?.Sex);
        dto.Nationality = Pick("nationality", saved?.Nationality, form?.Nationality);
        dto.EntranceData = Pick("entranceData", saved?.EntranceData, form?.LastSchoolAttended);
        dto.DateAdmitted = Clean(saved?.DateAdmitted);
        if (saved?.DateOfBirth != null)
        {
            dto.DateOfBirth = saved.DateOfBirth;
        }
        else if (form != null && form.DateOfBirth != default)
        {
            dto.DateOfBirth = form.DateOfBirth;
            dto.FromForm.Add("dateOfBirth");
        }
        return dto;
    }

    /// <summary>Saves the Registrar's details. Empty fields are stored empty, so they show the form's value again.</summary>
    public async Task<PersonalDetailsDto> UpdatePersonalDetailsAsync(Guid userId, UpdatePersonalDetailsDto dto, Guid updatedBy)
    {
        if (!await _context.UserDetails.AnyAsync(ud => ud.UserID == userId && ud.User != null && ud.User.Role == RoleUtils.Student))
        {
            throw new KeyNotFoundException("Student not found.");
        }
        if (dto.DateOfBirth is { } dob && (dob.Year < 1900 || dob > DateOnly.FromDateTime(DateTime.UtcNow)))
        {
            throw new InvalidOperationException("Date of birth is not valid.");
        }

        var saved = await _context.StudentPersonalDetails.FirstOrDefaultAsync(d => d.UserID == userId);
        if (saved == null)
        {
            saved = new StudentPersonalDetails { UserID = userId };
            _context.StudentPersonalDetails.Add(saved);
        }
        saved.MiddleName = Clean(dto.MiddleName);
        saved.Suffix = Clean(dto.Suffix);
        saved.Address = Clean(dto.Address);
        saved.DateOfBirth = dto.DateOfBirth;
        saved.PlaceOfBirth = Clean(dto.PlaceOfBirth);
        saved.Sex = Clean(dto.Sex);
        saved.Nationality = Clean(dto.Nationality);
        saved.EntranceData = Clean(dto.EntranceData);
        saved.DateAdmitted = Clean(dto.DateAdmitted);
        saved.UpdatedByUserID = updatedBy;
        saved.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return await GetPersonalDetailsAsync(userId);
    }

    private static string Ordinal(int n) => n switch { 1 => "1st", 2 => "2nd", 3 => "3rd", _ => $"{n}th" };
}
