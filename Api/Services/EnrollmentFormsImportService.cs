using System.Globalization;
using Api.Auth;
using Api.Common;
using Api.Domain.Enrollment;
using Api.DTOs.Enrollment;
using Api.DTOs.Records;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface IEnrollmentFormsImportService
{
    Task<EnrollmentFormsImportResultDto> ImportAsync(Stream file, bool dryRun, Guid callerId);
}

/// <summary>
/// Reads the Google Form's responses spreadsheet ("COLLEGE DEPARTMENT ENROLLMENT FORM (Responses).xlsx") and saves
/// each answer as the enrollment form of a student already in the system, matched by school email or by name.
/// The Details tab and online re-enrollment then use it, like a form sent through the system.
/// Rows of students who are not in the system are left out; importing the same file again changes nothing.
/// </summary>
public class EnrollmentFormsImportService : IEnrollmentFormsImportService
{
    private readonly AppDbContext _context;

    public EnrollmentFormsImportService(AppDbContext context)
    {
        _context = context;
    }

    /// <summary>Letters and digits only, upper case: "Suffix (ex. Jr., Sr., III)" → "SUFFIXEXJRSRIII".</summary>
    private static string Key(string s) => new(s.ToUpperInvariant().Where(char.IsAsciiLetterOrDigit).ToArray());

    private static string NameKey(string s) => new(s.ToUpperInvariant().Where(char.IsAsciiLetter).ToArray());

    /// <summary>The header row, as columns per header key; repeated titles keep their order (home address, then provincial).</summary>
    private sealed class Columns
    {
        private readonly Dictionary<string, List<int>> _map = new();

        public Columns(XlsxReader.Row header)
        {
            for (int i = 0; i < header.Cells.Count; i++)
            {
                var k = Key(header.Cells[i]);
                if (k.Length == 0) continue;
                if (!_map.TryGetValue(k, out var list)) _map[k] = list = new();
                list.Add(i);
            }
        }

        /// <summary>The column whose title is (or starts with) one of the names; <paramref name="nth"/> picks a repeated title.</summary>
        public int Find(string name, int nth = 0)
        {
            var k = Key(name);
            if (_map.TryGetValue(k, out var exact)) return nth < exact.Count ? exact[nth] : -1;
            var starts = _map.Where(e => e.Key.StartsWith(k) && !char.IsAsciiDigit(e.Key[^1]))
                .SelectMany(e => e.Value).Order().ToList();
            return nth < starts.Count ? starts[nth] : -1;
        }

        public bool Has(string name) => Find(name) >= 0;
    }

    private static DateTime? ExcelDateTime(string raw)
    {
        if (double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out var serial) && serial is > 1 and < 80000)
        {
            // Whole seconds, so the saved timestamp matches again on the next import.
            var dt = DateTime.FromOADate(serial);
            return new DateTime(dt.Year, dt.Month, dt.Day, dt.Hour, dt.Minute, dt.Second);
        }
        string[] formats = { "M/d/yyyy H:mm:ss", "M/d/yyyy", "yyyy-MM-dd", "MMMM d, yyyy", "d/M/yyyy" };
        return DateTime.TryParseExact(raw.Trim(), formats, CultureInfo.InvariantCulture, DateTimeStyles.None, out var d) ? d : null;
    }

    private static DateOnly? Date(string raw) => ExcelDateTime(raw) is { } d ? DateOnly.FromDateTime(d) : null;

    /// <summary>"2023" → Jan 1, 2023; a date → that date.</summary>
    private static DateOnly? YearOrDate(string raw)
    {
        if (int.TryParse(raw.Trim(), out var y) && y is >= 1950 and <= 2100) return new DateOnly(y, 1, 1);
        return Date(raw);
    }

    public static int? YearLevelOf(string raw) => Key(raw) switch
    {
        var k when k.StartsWith("FIRST") || k.StartsWith("1") => 1,
        var k when k.StartsWith("SECOND") || k.StartsWith("2") => 2,
        var k when k.StartsWith("THIRD") || k.StartsWith("3") => 3,
        var k when k.StartsWith("FOURTH") || k.StartsWith("4") => 4,
        var k when k.StartsWith("FIFTH") || k.StartsWith("5") => 5,
        _ => null,
    };

    public static int? StudentTypeOf(string raw) => Key(raw) switch
    {
        var k when k.StartsWith("NEW") => 1,
        var k when k.StartsWith("OLD") || k.StartsWith("RETURN") || k.StartsWith("CONTINU") => 2,
        var k when k.StartsWith("TRANSFER") => 3,
        _ => null,
    };

    private static List<string>? Many(string raw)
    {
        var parts = raw.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(p => p.Length > 0).Select(p => p.Length > 100 ? p[..100] : p).ToList();
        return parts.Count == 0 ? null : parts;
    }

    private static string Cut(string s, int max) => s.Length > max ? s[..max] : s;

    private sealed record Parsed(int Row, DateTime? Timestamp, string Email, EnrollmentFormDto Form, List<ContactDto> Contacts);

    public async Task<EnrollmentFormsImportResultDto> ImportAsync(Stream file, bool dryRun, Guid callerId)
    {
        var result = new EnrollmentFormsImportResultDto { DryRun = dryRun };
        void Problem(string sheet, int row, string message)
        {
            result.TotalProblems++;
            if (result.Problems.Count < 200) result.Problems.Add(new RecordsImportProblemDto { File = "Form responses", Sheet = sheet, Row = row, Message = message });
        }

        var sheets = XlsxReader.Read(file);
        var sheet = sheets.FirstOrDefault(s => s.Rows.Count > 0 && new Columns(s.Rows[0]) is var c && c.Has("Last Name") && c.Has("First Name"))
            ?? throw new InvalidDataException("This is not a Google Form responses file: the first row needs \"First Name\" and \"Last Name\".");
        var cols = new Columns(sheet.Rows[0]);
        string Get(XlsxReader.Row r, string name, int nth = 0) => cols.Find(name, nth) is var i and >= 0 ? r[i].Trim() : string.Empty;

        // ── Read every answer ──
        var parsed = new List<Parsed>();
        foreach (var r in sheet.Rows.Skip(1))
        {
            if (r.Cells.All(string.IsNullOrWhiteSpace)) continue;
            var first = Get(r, "First Name");
            var last = Get(r, "Last Name");
            if (first.Length == 0 || last.Length == 0)
            {
                Problem(sheet.Name, r.Number, "No first or last name.");
                continue;
            }
            var sex = RecordsImportService.SexOf(Get(r, "Gender")) ?? RecordsImportService.SexOf(Get(r, "Sex")) ?? string.Empty;
            var form = new EnrollmentFormDto
            {
                FirstName = Cut(RecordsImportService.NameCase(first), 100),
                MiddleName = Cut(RecordsImportService.NameCase(Get(r, "Middle Name")), 100),
                LastName = Cut(RecordsImportService.NameCase(last), 100),
                Suffix = Cut(Get(r, "Suffix"), 20),
                DateOfBirth = Date(Get(r, "Date of Birth")) ?? default,
                PlaceOfBirth = Cut(Get(r, "Place of Birth"), 200),
                Sex = sex,
                Gender = sex.Length > 0 ? sex : null,
                CivilStatus = Cut(Get(r, "Civil Status"), 50),
                Nationality = Cut(Get(r, "Nationality"), 100),
                Age = int.TryParse(Get(r, "Age"), NumberStyles.Float, CultureInfo.InvariantCulture, out var age) && age is > 0 and < 120 ? age : null,
                BloodType = NullIfEmpty(Cut(Get(r, "Blood Type"), 10)),
                Religion = NullIfEmpty(Cut(Get(r, "Religion"), 100)),
                FacebookName = NullIfEmpty(Cut(Get(r, "Input your Facebook Name"), 200)),
                MobileNumber = Cut(XlsxReader.WholeNumberText(Get(r, "Mobile Number")), 30),
                HouseStreet = NullIfEmpty(Cut(Get(r, "House No Unit No Street"), 200)),
                Barangay = Cut(Get(r, "Barangay"), 100),
                CityMunicipality = Cut(Get(r, "City of Municipality") is { Length: > 0 } city ? city : Get(r, "City Municipality"), 100),
                Province = Cut(Get(r, "Province"), 100),
                ZipCode = Cut(XlsxReader.WholeNumberText(Get(r, "Zip Code")), 10),
                ProvHouseStreet = NullIfEmpty(Cut(Get(r, "House No Unit No Street", 1), 200)),
                ProvBarangay = NullIfEmpty(Cut(Get(r, "Barangay 2"), 100)),
                ProvCityMunicipality = NullIfEmpty(Cut(cols.Has("City of Municipality") ? Get(r, "City Municipality") : Get(r, "City Municipality", 1), 100)),
                ProvProvince = NullIfEmpty(Cut(Get(r, "Province 2"), 100)),
                ProvZipCode = NullIfEmpty(Cut(XlsxReader.WholeNumberText(Get(r, "Zip Code 2")), 10)),
                LastSchoolAttended = Cut(Get(r, "Name of Last School Attended"), 200),
                SchoolAddress = Cut(Get(r, "Address of Last School Attended"), 300),
                ProgramTrackStrand = NullIfEmpty(Cut(Get(r, "Program Track"), 200)),
                YearGraduated = YearOrDate(Get(r, "Year of Last School Attended")) ?? default,
                PreviousCollege = Cut(Get(r, "Previous College"), 200),
                PreviousCourse = Cut(Get(r, "Previous Course"), 200),
                YearLevel = YearLevelOf(Get(r, "Incoming Year Level")) ?? 0,
                StudentType = StudentTypeOf(Get(r, "Student type")),
                LRN = Get(r, "Enter LRN"),
                AcademicYear = NullIfEmpty(Cut(Get(r, "Academic Year"), 20)),
                IncomingCourse = NullIfEmpty(Cut(Get(r, "Incoming Course"), 200)),
                BirthOrder = NullIfEmpty(Cut(Get(r, "Birth Order"), 50)),
                NumberOfSiblings = int.TryParse(Get(r, "Number of Siblings"), NumberStyles.Float, CultureInfo.InvariantCulture, out var sib) && sib is >= 0 and < 50 ? sib : null,
                FamilyStatus = NullIfEmpty(Cut(Get(r, "Family Status"), 100)),
                FamilyMedicalConditionsSelected = Many(Get(r, "Present Medical Conditions")),
                PastMedicalHistory = Many(Get(r, "Past Medical History")),
                ImmunizationHistory = Many(Get(r, "Immunization History")),
                FamilyMedicalConditionsNotes = NullIfEmpty(Cut(Get(r, "Please note any medical conditions"), 2000)),
                OngoingMedications = NullIfEmpty(Cut(Get(r, "Ongoing Medications"), 2000)),
                DevelopmentalConditions = NullIfEmpty(Cut(Get(r, "Developmental"), 2000)),
                OtherMedicalDiagnosis = NullIfEmpty(Cut(Get(r, "Medical Conditions Diagnosis"), 2000)),
            };

            // Father, mother, then guardian, in the order the form asks.
            var contacts = new List<ContactDto>();
            void Contact(int relation, string n, string occupation, string? workplace, string? facebook, bool withDob)
            {
                var cf = Get(r, "First Name " + n);
                var cl = Get(r, "Last Name " + n);
                if (cf.Length == 0 && cl.Length == 0) return;
                var living = Get(r, "This student is living with guardian");
                contacts.Add(new ContactDto
                {
                    FirstName = Cut(RecordsImportService.NameCase(cf), 100),
                    LastName = Cut(RecordsImportService.NameCase(cl), 100),
                    RelationType = relation,
                    Occupation = NullIfEmpty(Cut(Get(r, occupation), 100)),
                    ContactNo = Cut(XlsxReader.WholeNumberText(Get(r, "Mobile Number " + n)), 30),
                    Email = NullIfEmpty(Cut(Get(r, "Email Address " + n), 320)),
                    DateOfBirth = withDob ? Date(Get(r, "Date of Birth " + n)) : null,
                    Workplace = workplace == null ? null : NullIfEmpty(Cut(Get(r, workplace), 200)),
                    FacebookAccount = facebook == null ? null : NullIfEmpty(Cut(Get(r, facebook), 200)),
                    LivingWithGuardian = relation == 3 && living.Length > 0 ? Key(living) is "YES" or "TRUE" or "Y" : null,
                    GuardianRelationshipDescription = relation == 3 ? NullIfEmpty(Cut(Get(r, "Relationship"), 100)) : null,
                });
            }
            Contact(1, "2", "Occupation", "Workplace or Company", "Facebook Messenger Account if any", true);
            Contact(2, "3", "Occupation 2", "Workplace or Company 2", "Facebook Messenger Account if any 2", true);
            Contact(3, "4", "Occupation 3", null, null, false);

            parsed.Add(new Parsed(r.Number, ExcelDateTime(Get(r, "Timestamp")), Get(r, "Email Address").ToLowerInvariant(), form, contacts));
        }

        // ── Match to students: school email first, then a unique first + last name ──
        var students = await _context.UserDetails.AsNoTracking()
            .Where(d => d.User != null && d.User.Role == RoleUtils.Student)
            .Select(d => new { d.UserID, d.Firstname, d.Lastname, d.StudentID, d.ProgramID, d.YearLevel, Email = d.User!.Email })
            .ToListAsync();
        var byEmail = students.Where(s => s.Email.Length > 0).GroupBy(s => s.Email.ToLowerInvariant()).ToDictionary(g => g.Key, g => g.First());
        var byName = students.GroupBy(s => NameKey(s.Firstname) + "|" + NameKey(s.Lastname)).ToDictionary(g => g.Key, g => g.ToList());

        var matched = new Dictionary<Guid, (Parsed Answer, string StudentId, string Name, int? ProgramId, int YearLevel, string How)>();
        foreach (var p in parsed)
        {
            var how = "school email";
            var s = p.Email.Length > 0 && byEmail.TryGetValue(p.Email, out var e) ? e : null;
            if (s == null)
            {
                how = "name";
                var list = byName.GetValueOrDefault(NameKey(p.Form.FirstName) + "|" + NameKey(p.Form.LastName));
                if (list is { Count: > 1 })
                {
                    Problem(sheet.Name, p.Row, $"{list.Count} students are named {p.Form.FirstName} {p.Form.LastName}; add the school email to their profile to match.");
                    continue;
                }
                s = list?.Single();
            }
            if (s == null)
            {
                result.NotInSystem++;
                Problem(sheet.Name, p.Row, $"{p.Form.FirstName} {p.Form.LastName} is not in the system" +
                    (p.Form.StudentType == 1 ? " (a new student: review them in Form responses instead)." : "."));
                continue;
            }
            if (matched.TryGetValue(s.UserID, out var earlier))
            {
                result.OlderAnswersSkipped++;
                if ((p.Timestamp ?? DateTime.MinValue) <= (earlier.Answer.Timestamp ?? DateTime.MinValue)) continue;
            }
            matched[s.UserID] = (p, s.StudentID ?? "", $"{s.Lastname}, {s.Firstname}", s.ProgramID, s.YearLevel ?? 1, how);
        }

        // ── Skip answers already imported (same student and same form timestamp) ──
        var userIds = matched.Keys.ToList();
        var imported = (await _context.EnrollmentApplications.AsNoTracking()
                .Where(a => a.StudentUserID != null && userIds.Contains(a.StudentUserID.Value) && a.Response != null)
                .Select(a => new { a.StudentUserID, a.Response!.Timestamp })
                .ToListAsync())
            .Select(a => (a.StudentUserID!.Value, a.Timestamp)).ToHashSet();

        // The form is filed under the student's latest term with subjects, so it never counts as an online
        // enrollment for the term that is open (which would block the student from enrolling online).
        var latestTerm = (await _context.StudyLoads.AsNoTracking()
                .Where(l => userIds.Contains(l.UserID) && l.Class != null)
                .Select(l => new { l.UserID, l.Class!.TermID, l.Class.Term!.SchoolYear, l.Class.Term.Semester })
                .ToListAsync())
            .GroupBy(l => l.UserID)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(t => t.SchoolYear).ThenByDescending(t => t.Semester).First().TermID);
        var oldestTerm = await _context.AcademicTerms.AsNoTracking().OrderBy(t => t.SchoolYear).ThenBy(t => t.Semester)
            .Select(t => (Guid?)t.TermID).FirstOrDefaultAsync();

        var toSave = new List<(Guid UserId, Parsed Answer, int ProgramId, Guid TermId)>();
        foreach (var (userId, m) in matched)
        {
            var stamp = m.Answer.Timestamp is { } t ? DateTime.SpecifyKind(t, DateTimeKind.Utc) : DateTime.MinValue;
            if (m.Answer.Timestamp != null && imported.Contains((userId, stamp)))
            {
                result.AlreadyImported++;
                continue;
            }
            if (m.ProgramId is not { } programId)
            {
                Problem(sheet.Name, m.Answer.Row, $"{m.Name} has no program yet; set it first.");
                continue;
            }
            var termId = latestTerm.TryGetValue(userId, out var lt) ? lt : oldestTerm;
            if (termId is not { } tid)
            {
                Problem(sheet.Name, m.Answer.Row, "There are no terms in the system yet.");
                continue;
            }
            if (m.Answer.Form.YearLevel == 0) m.Answer.Form.YearLevel = m.YearLevel;
            toSave.Add((userId, m.Answer, programId, tid));
            result.Rows.Add(new EnrollmentFormsImportRowDto
            {
                Row = m.Answer.Row,
                StudentId = m.StudentId,
                StudentName = m.Name,
                MatchedBy = m.How,
                Contacts = m.Answer.Contacts.Count,
            });
        }
        result.Forms = toSave.Count;

        if (!dryRun && toSave.Count > 0)
        {
            foreach (var (userId, answer, programId, termId) in toSave)
            {
                var response = new EnrollmentResponse
                {
                    ResponseID = Guid.NewGuid(),
                    Timestamp = answer.Timestamp is { } t ? DateTime.SpecifyKind(t, DateTimeKind.Utc) : DateTime.UtcNow,
                    EmailAddress = Cut(answer.Email, 320),
                    IsProcessed = true, // never shown in Form responses
                };
                _context.EnrollmentResponses.Add(response);
                var application = new EnrollmentApplication
                {
                    ApplicationID = Guid.NewGuid(),
                    ResponseID = response.ResponseID,
                    ProgramID = programId,
                    TermID = termId,
                    Status = EnrollmentApplicationStatus.Active,
                    StudentUserID = userId,
                    ReviewedByUserID = callerId,
                    CreatedByUserID = callerId,
                    CreatedAt = DateTime.UtcNow,
                };
                _context.EnrollmentApplications.Add(application);
                var form = EnrollmentFormMapping.ToEntity(answer.Form, application.ApplicationID);
                _context.EnrollmentForms.Add(form);
                foreach (var c in answer.Contacts) _context.Contacts.Add(EnrollmentFormMapping.ToEntity(c, form.EnrollmentID));
            }
            await _context.SaveChangesAsync();
        }
        return result;
    }

    private static string? NullIfEmpty(string s) => string.IsNullOrWhiteSpace(s) ? null : s;
}
