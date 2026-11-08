using System.Text.Json;
using System.Text.RegularExpressions;
using Api.Auth;
using Api.Common;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.DTOs.Enrollment;
using Api.DTOs.Reenrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface IReenrollmentService
{
    /// <summary>Where the student stands for the term open today, with last time's form when they can enroll.</summary>
    Task<ReenrollmentStatusDto> GetStatusAsync(Guid studentId, DateOnly today);

    /// <summary>Saves the enrollment as a Pending application for the Registrar. Returns it with the changed fields.</summary>
    Task<(Guid ApplicationId, string TermLabel, List<string> Changed)> SubmitAsync(Guid studentId, SubmitReenrollmentDto dto, DateOnly today);
}

/// <summary>
/// Old students enrolling again from the Student Portal. Everything is checked here, on the server: the student
/// comes from their sign-in only, the term must be open, they must be cleared for their last term with no holds,
/// and fields they may not change are copied from their record whatever the app sends.
/// </summary>
public partial class ReenrollmentService : IReenrollmentService
{
    private readonly AppDbContext _context;

    public ReenrollmentService(AppDbContext context)
    {
        _context = context;
    }

    /// <summary>Kept from the record: name, birth, sex, LRN and schooling before DBTC change only through the Registrar.</summary>
    public static readonly string[] LockedFields =
    {
        nameof(EnrollmentFormDto.FirstName), nameof(EnrollmentFormDto.MiddleName), nameof(EnrollmentFormDto.LastName),
        nameof(EnrollmentFormDto.Suffix), nameof(EnrollmentFormDto.DateOfBirth), nameof(EnrollmentFormDto.PlaceOfBirth),
        nameof(EnrollmentFormDto.Sex), nameof(EnrollmentFormDto.LRN),
        nameof(EnrollmentFormDto.LastSchoolAttended), nameof(EnrollmentFormDto.SchoolAddress),
        nameof(EnrollmentFormDto.ProgramTrackStrand), nameof(EnrollmentFormDto.YearGraduated),
        nameof(EnrollmentFormDto.PreviousCollege), nameof(EnrollmentFormDto.PreviousCourse),
        nameof(EnrollmentFormDto.PreviousStudentID),
    };

    // Set by the server, so never counted as a change.
    private static readonly string[] SetByServer =
    {
        nameof(EnrollmentFormDto.YearLevel), nameof(EnrollmentFormDto.StudentType), nameof(EnrollmentFormDto.AcademicYear),
        nameof(EnrollmentFormDto.IncomingCourse), nameof(EnrollmentFormDto.CityOfMunicipality), nameof(EnrollmentFormDto.Age),
    };

    private sealed record Situation(
        ReenrollmentStatusDto Status,
        AcademicTerm? Term,
        EnrollmentForm? Source,
        List<Contact> SourceContacts,
        Domain.IdentityAccess.UserDetails? Details);

    public async Task<ReenrollmentStatusDto> GetStatusAsync(Guid studentId, DateOnly today) =>
        (await LookAsync(studentId, today)).Status;

    private async Task<Situation> LookAsync(Guid studentId, DateOnly today)
    {
        ReenrollmentStatusDto status = new() { State = ReenrollmentStates.Closed, LockedFields = LockedFields.ToList() };
        Situation Done(AcademicTerm? term = null, EnrollmentForm? source = null, List<Contact>? contacts = null,
                       Domain.IdentityAccess.UserDetails? details = null) =>
            new(status, term, source, contacts ?? new(), details);

        var term = (await _context.AcademicTerms.AsNoTracking()
                .Where(t => t.EnrollmentOpensOn != null && t.EnrollmentClosesOn != null &&
                            t.EnrollmentOpensOn <= today && t.EnrollmentClosesOn >= today)
                .ToListAsync())
            .OrderBy(t => t.EnrollmentClosesOn)
            .FirstOrDefault();
        if (term == null) return Done();

        status.TermId = term.TermID;
        status.TermLabel = TermLabel.Format(term.SchoolYear, term.Semester);
        status.OpensOn = term.EnrollmentOpensOn;
        status.ClosesOn = term.EnrollmentClosesOn;

        var details = await _context.UserDetails.AsNoTracking()
            .Include(d => d.Program)
            .FirstOrDefaultAsync(d => d.UserID == studentId && d.User != null && d.User.Role == RoleUtils.Student);
        if (details == null)
        {
            return NotEligible("We could not find your student record. Please see the Registrar.");
        }
        status.ProgramCode = details.Program?.ProgramCode;
        status.ProgramName = details.Program?.ProgramName;
        status.CurrentYearLevel = details.YearLevel;

        Situation NotEligible(string reason)
        {
            status.State = ReenrollmentStates.NotEligible;
            status.Reasons.Add(reason);
            return Done(term, details: details);
        }

        // Already sent for this term (a rejected one can be sent again).
        var sent = await _context.EnrollmentApplications.AsNoTracking()
            .Where(a => a.StudentUserID == studentId && a.TermID == term.TermID &&
                        a.Status != EnrollmentApplicationStatus.Rejected)
            .OrderByDescending(a => a.CreatedAt)
            .FirstOrDefaultAsync();
        if (sent != null)
        {
            status.State = ReenrollmentStates.Submitted;
            status.SubmittedAt = sent.CreatedAt;
            status.ApplicationStatus = EnrollmentApplicationStatus.GetName(sent.Status);
            return Done(term, details: details);
        }

        if (details.ProgramID == null)
        {
            return NotEligible("Your program is not set. Please see the Registrar.");
        }

        bool hasLoadThisTerm = await _context.StudyLoads.AsNoTracking().AnyAsync(sl =>
            sl.UserID == studentId && sl.Class != null && sl.Class.TermID == term.TermID &&
            (sl.LoadStatus == StudyLoadStatus.Enrolled || sl.LoadStatus == StudyLoadStatus.Pending));
        if (hasLoadThisTerm)
        {
            return NotEligible($"You already have a study load for {status.TermLabel}.");
        }

        // The last term the student was enrolled in, before this one.
        var lastTerm = (await _context.StudyLoads.AsNoTracking()
                .Where(sl => sl.UserID == studentId && sl.LoadStatus == StudyLoadStatus.Enrolled &&
                             sl.Class != null && sl.Class.Term != null)
                .Select(sl => sl.Class!.Term!)
                .Distinct()
                .ToListAsync())
            .Where(t => IsBefore(t, term))
            .OrderByDescending(t => t.SchoolYear).ThenByDescending(t => t.Semester)
            .FirstOrDefault();
        if (lastTerm == null)
        {
            return NotEligible("We could not find an earlier term you were enrolled in. Please see the Registrar.");
        }

        var (source, contacts) = await LatestFormAsync(studentId);
        if (source == null)
        {
            return NotEligible("We don't have your enrollment form on file. Please see the Registrar.");
        }

        var lastLabel = TermLabel.Format(lastTerm.SchoolYear, lastTerm.Semester);
        bool cleared = await _context.GradeClearances.AsNoTracking()
            .AnyAsync(c => c.UserID == studentId && c.TermID == lastTerm.TermID && c.IsCleared);
        if (!cleared) status.Reasons.Add($"You are not yet cleared for {lastLabel}.");

        var holds = await _context.EnrollmentHolds.AsNoTracking()
            .Where(h => h.UserID == studentId && h.RemovedAt == null)
            .Select(h => h.Reason)
            .ToListAsync();
        foreach (var reason in holds.Distinct())
        {
            status.Reasons.Add($"You have a hold: {EnrollmentHoldReasons.Label(reason)}.");
        }

        if (status.Reasons.Count > 0)
        {
            status.Reasons.Add("Please see the Registrar.");
            status.State = ReenrollmentStates.OnHold;
            return Done(term, source, contacts, details);
        }

        int current = details.YearLevel ?? source.YearLevel;
        status.YearLevelChoices = new[] { current, current + 1 }.Where(y => y is >= 1 and <= 5).Distinct().ToList();
        status.State = ReenrollmentStates.Ready;
        status.Form = EnrollmentFormMapping.ToDto(source);
        status.Form.YearLevel = current;
        status.Contacts = contacts.OrderBy(c => c.RelationType).Select(EnrollmentFormMapping.ToDto).ToList();
        status.FilledFromTerm = await _context.EnrollmentApplications.AsNoTracking()
            .Where(a => a.ApplicationID == source.ApplicationID && a.Term != null)
            .Select(a => TermLabel.Format(a.Term!.SchoolYear, a.Term.Semester))
            .FirstOrDefaultAsync();
        return Done(term, source, contacts, details);
    }

    private static bool IsBefore(AcademicTerm a, AcademicTerm b) =>
        string.CompareOrdinal(a.SchoolYear.Trim(), b.SchoolYear.Trim()) switch
        {
            < 0 => true,
            > 0 => false,
            _ => a.Semester < b.Semester,
        };

    /// <summary>
    /// The student's latest form that the Registrar accepted (or a new student's form). A rejected application,
    /// or a returning one still waiting, is not used.
    /// </summary>
    private async Task<(EnrollmentForm? Form, List<Contact> Contacts)> LatestFormAsync(Guid studentId)
    {
        var form = await _context.EnrollmentForms.AsNoTracking()
            .Where(f => f.Application != null && f.Application.StudentUserID == studentId &&
                        f.Application.Status != EnrollmentApplicationStatus.Rejected &&
                        !(f.Application.IsReturning && f.Application.Status == EnrollmentApplicationStatus.Pending))
            .OrderByDescending(f => f.Application!.CreatedAt)
            .FirstOrDefaultAsync();
        if (form == null) return (null, new());
        var contacts = await _context.Contacts.AsNoTracking().Where(c => c.EnrollmentID == form.EnrollmentID).ToListAsync();
        return (form, contacts);
    }

    public async Task<(Guid ApplicationId, string TermLabel, List<string> Changed)> SubmitAsync(
        Guid studentId, SubmitReenrollmentDto dto, DateOnly today)
    {
        var look = await LookAsync(studentId, today);
        var status = look.Status;
        if (status.State != ReenrollmentStates.Ready)
        {
            throw new InvalidOperationException(status.State switch
            {
                ReenrollmentStates.Closed => "Online enrollment is closed.",
                ReenrollmentStates.Submitted => $"You already sent your enrollment for {status.TermLabel}.",
                _ => string.Join(" ", status.Reasons),
            });
        }
        if (dto.TermId != look.Term!.TermID)
        {
            throw new InvalidOperationException($"Online enrollment is open for {status.TermLabel} only. Please reload the page.");
        }
        if (!dto.Confirmed)
        {
            throw new InvalidOperationException("Please tick \"I checked my information and it is correct\".");
        }
        if (!status.YearLevelChoices.Contains(dto.YearLevel))
        {
            throw new InvalidOperationException(
                $"Year level must be {string.Join(" or ", status.YearLevelChoices)}. The Registrar can change it if needed.");
        }
        var contactTypes = dto.Contacts.Select(c => c.RelationType).ToList();
        if (contactTypes.Any(t => t is < 1 or > 3) || contactTypes.Distinct().Count() != contactTypes.Count)
        {
            throw new InvalidOperationException("Contacts must be one father, one mother and one guardian at most.");
        }

        var source = look.Source!;
        var details = look.Details!;
        var program = await _context.AcademicPrograms.AsNoTracking().FirstAsync(p => p.ProgramID == details.ProgramID);

        // Start from what the student sent, then put back everything they may not change.
        var form = dto.Form;
        var kept = EnrollmentFormMapping.ToDto(source);
        foreach (var name in LockedFields)
        {
            var prop = typeof(EnrollmentFormDto).GetProperty(name)!;
            prop.SetValue(form, prop.GetValue(kept));
        }
        form.YearLevel = dto.YearLevel;
        form.StudentType = 2; // Old student
        form.AcademicYear = look.Term.SchoolYear;
        form.IncomingCourse = program.ProgramCode;
        form.Age = AgeOn(form.DateOfBirth, today) ?? kept.Age;

        var changed = ChangedFields(kept, form, look.SourceContacts, dto.Contacts);

        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            var email = await _context.Users.Where(u => u.UserID == studentId).Select(u => u.Email).FirstAsync();
            var response = new EnrollmentResponse
            {
                ResponseID = Guid.NewGuid(),
                Timestamp = DateTime.UtcNow,
                EmailAddress = email,
                IsProcessed = true, // never shown in Form responses
            };
            _context.EnrollmentResponses.Add(response);

            var application = new EnrollmentApplication
            {
                ApplicationID = Guid.NewGuid(),
                ResponseID = response.ResponseID,
                ProgramID = program.ProgramID,
                TermID = look.Term.TermID,
                Status = EnrollmentApplicationStatus.Pending,
                StudentUserID = studentId,
                CreatedByUserID = studentId,
                CreatedAt = DateTime.UtcNow,
                IsReturning = true,
                ChangedFields = changed.Count == 0 ? null : Truncate(string.Join(", ", changed), 2000),
            };
            _context.EnrollmentApplications.Add(application);

            var entity = EnrollmentFormMapping.ToEntity(form, application.ApplicationID);
            _context.EnrollmentForms.Add(entity);
            foreach (var c in dto.Contacts)
            {
                _context.Contacts.Add(EnrollmentFormMapping.ToEntity(c, entity.EnrollmentID));
            }

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return (application.ApplicationID, status.TermLabel!, changed);
        }
        catch (DbUpdateException)
        {
            // The one-application-per-term index caught a second submission at the same moment.
            await transaction.RollbackAsync();
            throw new InvalidOperationException($"You already sent your enrollment for {status.TermLabel}.");
        }
    }

    private static int? AgeOn(DateOnly birth, DateOnly today)
    {
        if (birth == default || birth > today) return null;
        int age = today.Year - birth.Year;
        if (birth > today.AddYears(-age)) age--;
        return age;
    }

    private static string Truncate(string text, int max) => text.Length <= max ? text : text[..max];

    [GeneratedRegex("(?<=[a-z])(?=[A-Z])")]
    private static partial Regex WordBreak();

    private static readonly Dictionary<string, string> Labels = new()
    {
        [nameof(EnrollmentFormDto.CityMunicipality)] = "City / Municipality",
        [nameof(EnrollmentFormDto.HouseStreet)] = "House / Street",
        [nameof(EnrollmentFormDto.ProvHouseStreet)] = "Provincial House / Street",
        [nameof(EnrollmentFormDto.ProvBarangay)] = "Provincial Barangay",
        [nameof(EnrollmentFormDto.ProvCityMunicipality)] = "Provincial City / Municipality",
        [nameof(EnrollmentFormDto.ProvProvince)] = "Provincial Province",
        [nameof(EnrollmentFormDto.ProvZipCode)] = "Provincial ZIP Code",
        [nameof(EnrollmentFormDto.ZipCode)] = "ZIP Code",
        [nameof(EnrollmentFormDto.FamilyMedicalConditionsSelected)] = "Family Medical Conditions",
    };

    /// <summary>"Mobile Number", "Barangay", "Father"... in form order.</summary>
    public static List<string> ChangedFields(
        EnrollmentFormDto before, EnrollmentFormDto after, List<Contact> contactsBefore, List<ContactDto> contactsAfter)
    {
        var changed = new List<string>();
        foreach (var prop in typeof(EnrollmentFormDto).GetProperties())
        {
            if (LockedFields.Contains(prop.Name) || SetByServer.Contains(prop.Name)) continue;
            if (Same(prop.GetValue(before), prop.GetValue(after))) continue;
            changed.Add(Labels.GetValueOrDefault(prop.Name) ?? WordBreak().Replace(prop.Name, " "));
        }

        foreach (var (type, label) in new[] { (1, "Father"), (2, "Mother"), (3, "Guardian") })
        {
            var old = contactsBefore.FirstOrDefault(c => c.RelationType == type);
            var now = contactsAfter.FirstOrDefault(c => c.RelationType == type);
            if (!Same(old == null ? null : EnrollmentFormMapping.ToDto(old), now)) changed.Add(label);
        }
        return changed;
    }

    private static bool Same(object? a, object? b)
    {
        static string Text(object? v) => v switch
        {
            null => "",
            string s => s.Trim(),
            _ => JsonSerializer.Serialize(v),
        };
        return Text(a) == Text(b) || (IsEmptyList(a) && IsEmptyList(b));
    }

    private static bool IsEmptyList(object? v) => v is null || v is System.Collections.ICollection { Count: 0 } || v is "";
}
