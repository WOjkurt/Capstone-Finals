using System.Globalization;
using System.Text.RegularExpressions;
using Api.Common;
using Api.DTOs.Enrollment;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface IPublicEnrollmentService
{
    /// <summary>Whether anyone may enrol today, and the courses they can pick. Safe to serve to a stranger.</summary>
    Task<PublicEnrollmentStatusDto> GetStatusAsync(DateOnly today);

    /// <summary>Records an applicant's form as an unprocessed response for the Registrar to review.</summary>
    Task<PublicEnrollmentReceiptDto> SubmitAsync(CreateEnrollmentResponseDto dto, DateOnly today);
}

/// <summary>
/// Applying to DBTC with no account yet — the one thing in the system a stranger can write to.
///
/// Everything an applicant sends is treated as a claim, not a fact: it lands as an unprocessed
/// EnrollmentResponse, exactly where a Google Forms submission lands, and becomes a student only
/// when the Registrar processes it. Nothing here creates a user, a login, or an application.
///
/// The enrollment window is the real gate. Outside it the endpoint refuses, which means the one
/// anonymous write in the system is shut for most of the year without anyone having to turn it off.
/// </summary>
public partial class PublicEnrollmentService : IPublicEnrollmentService
{
    private readonly AppDbContext _context;
    private readonly IEnrollmentService _enrollment;

    /// <summary>A first-time applicant (1) or someone transferring in from another school (3).</summary>
    public static readonly int[] AcceptedStudentTypes = { 1, 3 };

    public PublicEnrollmentService(AppDbContext context, IEnrollmentService enrollment)
    {
        _context = context;
        _enrollment = enrollment;
    }

    /// <summary>The term whose enrollment window covers today; the one closing soonest if several do.</summary>
    private async Task<Domain.Enrollment.AcademicTerm?> OpenTermAsync(DateOnly today) =>
        (await _context.AcademicTerms.AsNoTracking()
            .Where(t => t.EnrollmentOpensOn != null && t.EnrollmentClosesOn != null &&
                        t.EnrollmentOpensOn <= today && t.EnrollmentClosesOn >= today)
            .ToListAsync())
        .OrderBy(t => t.EnrollmentClosesOn)
        .FirstOrDefault();

    public async Task<PublicEnrollmentStatusDto> GetStatusAsync(DateOnly today)
    {
        var term = await OpenTermAsync(today);
        if (term == null) return new PublicEnrollmentStatusDto { IsOpen = false };

        var programs = await _context.AcademicPrograms.AsNoTracking()
            .OrderBy(p => p.ProgramCode)
            .Select(p => new PublicProgramDto
            {
                ProgramId = p.ProgramID,
                ProgramCode = p.ProgramCode,
                ProgramName = p.ProgramName
            })
            .ToListAsync();

        return new PublicEnrollmentStatusDto
        {
            IsOpen = true,
            TermLabel = TermLabel.Format(term.SchoolYear, term.Semester),
            ClosesOn = term.EnrollmentClosesOn,
            Programs = programs
        };
    }

    public async Task<PublicEnrollmentReceiptDto> SubmitAsync(CreateEnrollmentResponseDto dto, DateOnly today)
    {
        var term = await OpenTermAsync(today)
            ?? throw new InvalidOperationException(
                "Online enrollment is closed right now. Please check back when the next enrollment period opens.");

        var form = dto.Form ?? throw new InvalidOperationException("The enrollment form is empty.");

        // Lower-cased like the Excel importer does with the Google Form's address column, so the
        // same applicant does not appear twice to the Registrar for having capitalised their name.
        var email = (dto.EmailAddress ?? string.Empty).Trim().ToLowerInvariant();
        if (email.Length > 320 || !Email().IsMatch(email))
        {
            throw new InvalidOperationException(
                "That does not look like an email address. The Registrar replies to this, so it has to be right.");
        }
        dto.EmailAddress = email;

        Required(form.FirstName, "First name");
        Required(form.LastName, "Last name");

        // Dates are checked here and rewritten as yyyy-MM-dd, not left as the applicant typed
        // them. The Registrar's own form takes a real date for both of these, so a blank or a
        // "dunno" would reach them as a response they cannot save without retyping it -- and the
        // applicant would be long gone by then. A date picker in the page is not enough on its
        // own: this endpoint is open, so anything can be posted to it.
        form.DateOfBirth = Date(form.DateOfBirth, "Date of birth");
        form.YearGraduated = Date(form.YearGraduated, "Year of last school attended");
        foreach (var contact in dto.Contacts)
        {
            // Optional for a contact, but still a date when it is given.
            if (!string.IsNullOrWhiteSpace(contact.DateOfBirth))
            {
                contact.DateOfBirth = Date(contact.DateOfBirth, $"Date of birth for {contact.FirstName} {contact.LastName}".Trim());
            }
        }

        if (form.StudentType is not { } type || !AcceptedStudentTypes.Contains(type))
        {
            throw new InvalidOperationException(
                "Choose whether you are enrolling as a new student or transferring from another school. "
                + "Students already studying at DBTC enrol through the Student Portal instead.");
        }

        if (string.IsNullOrWhiteSpace(form.IncomingCourse))
        {
            throw new InvalidOperationException("Choose the course you are applying for.");
        }

        // Set here, not taken from the applicant: which term they are applying for is the school's
        // fact, and a first-year starts at year 1. A transferee's year level is left for the
        // Registrar, who decides it from the credits they end up granting. Age is worked out from
        // the birthday for the same reason it is on re-enrollment -- the Registrar's printouts
        // want one, and an applicant's own arithmetic is not worth trusting or asking for.
        form.AcademicYear = term.SchoolYear;
        form.StudentType = type;
        form.Age = Ages.On(form.DateOfBirth, today);

        // A first-year can only be entering year 1, whatever was sent. A transferee's own answer
        // is kept when it is a real year level, because it tells the Registrar where to start
        // looking -- but it stays a claim on an unprocessed response, not a decision.
        form.YearLevel = type == 1
            ? 1
            : (form.YearLevel is >= 1 and <= 4 ? form.YearLevel : null);

        // Someone enrolling as a first-year has no previous college, whatever arrived in the
        // request. Left in, they reach the Registrar looking like a transferee with credits to
        // record. The page clears these when the applicant switches back, but the page is not
        // the only thing that can post here.
        if (type == 1)
        {
            form.PreviousCollege = null;
            form.PreviousCourse = null;
            form.PreviousStudentID = null;
        }

        var responseId = await _enrollment.CreateResponseAsync(dto);

        return new PublicEnrollmentReceiptDto
        {
            ResponseId = responseId,
            Reference = ReferenceFor(responseId),
            TermLabel = TermLabel.Format(term.SchoolYear, term.Semester),
            SubmittedAt = DateTime.UtcNow
        };
    }

    /// <summary>Short enough to write on a scrap of paper or read out over the phone.</summary>
    public static string ReferenceFor(Guid responseId) =>
        responseId.ToString().Split('-')[0].ToUpperInvariant();

    private static void Required(string? value, string what)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"{what} is required.");
        }
    }

    /// <summary>
    /// A date the Registrar's form will accept, written as yyyy-MM-dd. A bare year counts, the way
    /// the Excel importer reads the Google Form's "year of last school attended" column.
    /// </summary>
    private static string Date(string? raw, string what)
    {
        var text = (raw ?? string.Empty).Trim();
        if (text.Length == 0) throw new InvalidOperationException($"{what} is required.");

        if (int.TryParse(text, out var year) && year is >= 1900 and <= 2100)
        {
            return new DateOnly(year, 1, 1).ToString("yyyy-MM-dd");
        }
        if (DateOnly.TryParse(text, CultureInfo.InvariantCulture, out var exact) ||
            DateOnly.TryParse(text, out exact))
        {
            return exact.ToString("yyyy-MM-dd");
        }
        throw new InvalidOperationException($"{what} is not a date we can read. Use a day, month and year.");
    }

    /// <summary>Something with a name, an @, and a domain that has a dot in it.</summary>
    [GeneratedRegex(@"^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$")]
    private static partial Regex Email();
}
