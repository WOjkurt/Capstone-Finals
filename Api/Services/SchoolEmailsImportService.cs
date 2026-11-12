using Api.Auth;
using Api.Common;
using Api.DTOs.Enrollment;
using Api.DTOs.Records;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface ISchoolEmailsImportService
{
    Task<SchoolEmailsImportResultDto> ImportAsync(Stream file, string fileName, bool dryRun, string allowedDomain);
}

/// <summary>
/// Adds the school emails of imported students from the IT department's list (.xlsx or .csv), so they can sign in.
/// Each row needs an email and either a Student ID or the student's name. Like setting the email by hand, only
/// students who haven't signed in yet are changed; their first sign-in with this email makes the account theirs.
/// </summary>
public class SchoolEmailsImportService : ISchoolEmailsImportService
{
    public const int MaxListedRows = 500;

    private readonly AppDbContext _context;

    public SchoolEmailsImportService(AppDbContext context) => _context = context;

    private static string Key(string header) => new(header.ToUpperInvariant().Where(char.IsAsciiLetter).ToArray());
    private static string NameKey(string s) => new(s.ToUpperInvariant().Where(char.IsAsciiLetter).ToArray());
    private static List<string> Words(string s) =>
        s.Split(new[] { ' ', '.', '-' }, StringSplitOptions.RemoveEmptyEntries).Select(NameKey).Where(w => w.Length > 0).ToList();

    private static readonly string[] StudentIdHeaders = { "STUDENTID", "STUDENTNO", "STUDENTNUMBER", "IDNO", "IDNUMBER", "ID" };
    private static readonly string[] EmailHeaders = { "SCHOOLEMAIL", "EMAIL", "EMAILADDRESS", "DBTCEMAIL", "INSTITUTIONALEMAIL", "GSUITEEMAIL", "GOOGLEACCOUNT", "USERNAME", "PRIMARYEMAIL" };
    private static readonly string[] LastNameHeaders = { "LASTNAME", "SURNAME", "FAMILYNAME" };
    private static readonly string[] FirstNameHeaders = { "FIRSTNAME", "GIVENNAME" };
    private static readonly string[] FullNameHeaders = { "STUDENTNAME", "NAME", "FULLNAME" };

    private static int Col(Dictionary<string, int> map, string[] names)
    {
        foreach (var n in names) if (map.TryGetValue(n, out var i)) return i;
        return -1;
    }

    private sealed record Line(string Sheet, int Row, string RawId, string? Id, string Email, string Last, string First, string FullName);

    public async Task<SchoolEmailsImportResultDto> ImportAsync(Stream file, string fileName, bool dryRun, string allowedDomain)
    {
        var result = new SchoolEmailsImportResultDto { DryRun = dryRun };
        void Problem(string sheet, int row, string message)
        {
            result.TotalProblems++;
            if (result.Problems.Count < 200) result.Problems.Add(new RecordsImportProblemDto { File = "School emails", Sheet = sheet, Row = row, Message = message });
        }

        // ── Read every sheet that has an email column and a Student ID or name column ──
        var lines = new List<Line>();
        bool anyHeader = false;
        foreach (var (sheet, rows) in CreditsImportService.ReadFile(file, fileName))
        {
            int headerIndex = -1, cId = -1, cEmail = -1, cLast = -1, cFirst = -1, cFull = -1;
            for (int i = 0; i < Math.Min(rows.Count, 10) && headerIndex < 0; i++)
            {
                var map = new Dictionary<string, int>();
                for (int c = 0; c < rows[i].Cells.Count; c++) map.TryAdd(Key(rows[i].Cells[c]), c);
                cEmail = Col(map, EmailHeaders);
                cId = Col(map, StudentIdHeaders);
                cLast = Col(map, LastNameHeaders);
                cFirst = Col(map, FirstNameHeaders);
                cFull = Col(map, FullNameHeaders);
                if (cEmail >= 0 && (cId >= 0 || (cLast >= 0 && cFirst >= 0) || cFull >= 0)) headerIndex = i;
            }
            if (headerIndex < 0) continue;
            anyHeader = true;
            string Cell(IReadOnlyList<string> cells, int i) => i >= 0 && i < cells.Count ? cells[i].Trim() : string.Empty;
            foreach (var (number, cells) in rows.Skip(headerIndex + 1))
            {
                var email = Cell(cells, cEmail).ToLowerInvariant();
                var rawId = XlsxReader.WholeNumberText(Cell(cells, cId));
                var last = Cell(cells, cLast);
                var first = Cell(cells, cFirst);
                var full = Cell(cells, cFull);
                if (email.Length == 0 && rawId.Length == 0 && last.Length == 0 && full.Length == 0) continue; // blank row
                var id = StudentIdHelper.Normalize(rawId);
                lines.Add(new Line(sheet, number, rawId, id.IsValid ? id.Number : null, email, last, first, full));
            }
        }
        if (!anyHeader)
        {
            throw new InvalidDataException("No header row was found. The list needs an Email column and a Student ID column " +
                                           "(or Last Name and First Name).");
        }

        // ── Students and the emails already used ──
        var students = await _context.UserDetails
            .Where(d => d.User != null && d.User.Role == RoleUtils.Student)
            .Select(d => new { d.UserID, d.StudentID, d.Firstname, d.Lastname, d.User!.Email, d.User.FirebaseUID })
            .ToListAsync();
        var byId = students.Where(s => !string.IsNullOrEmpty(s.StudentID)).GroupBy(s => s.StudentID!).ToDictionary(g => g.Key, g => g.First());
        var byLast = students.GroupBy(s => NameKey(s.Lastname)).ToDictionary(g => g.Key, g => g.ToList());
        var emailOwners = (await _context.Users.AsNoTracking().Where(u => u.Email != "").Select(u => new { u.UserID, u.Email }).ToListAsync())
            .GroupBy(u => u.Email.ToLowerInvariant()).ToDictionary(g => g.Key, g => g.First().UserID);
        var nameOf = students.ToDictionary(s => s.UserID, s => $"{s.Lastname}, {s.Firstname}");

        // ── Match each line ──
        var planned = new Dictionary<Guid, (Line Line, string How)>();
        var emailInFile = new Dictionary<string, Guid>();
        var conflicted = new HashSet<Guid>();
        foreach (var l in lines)
        {
            if (l.Email.Length == 0)
            {
                Problem(l.Sheet, l.Row, "No email; row skipped.");
                continue;
            }
            if (!System.Net.Mail.MailAddress.TryCreate(l.Email, out var parsed) || parsed.Address != l.Email ||
                !SchoolEmailValidator.IsValidDomain(l.Email, allowedDomain))
            {
                Problem(l.Sheet, l.Row, $"\"{l.Email}\" is not a school email (it must end with @{allowedDomain}); row skipped.");
                continue;
            }

            Guid? userId = null;
            string how = "Student ID";
            if (l.RawId.Length > 0)
            {
                if (l.Id == null)
                {
                    Problem(l.Sheet, l.Row, $"Student ID \"{l.RawId}\" is not valid; row skipped.");
                    continue;
                }
                if (byId.TryGetValue(l.Id, out var s)) userId = s.UserID;
            }
            else
            {
                how = "name";
                var (last, rest) = l.Last.Length > 0 ? (l.Last, l.First)
                    : l.FullName.Split(',', 2) is { Length: 2 } parts ? (parts[0], parts[1]) : ("", "");
                if (last.Length == 0)
                {
                    Problem(l.Sheet, l.Row, "No Student ID, and the name isn't written as \"LAST NAME, FIRST NAME\"; row skipped.");
                    continue;
                }
                // The first name in the list may also hold the middle name ("ANA MARIE SANTOS"), so a first name that
                // starts it counts; only one such student may match.
                var restWords = Words(rest);
                var found = (byLast.GetValueOrDefault(NameKey(last)) ?? new())
                    .Where(s => Words(s.Firstname) is { Count: > 0 } fw && fw.Count <= restWords.Count && fw.SequenceEqual(restWords.Take(fw.Count)))
                    .ToList();
                if (found.Count > 1)
                {
                    Problem(l.Sheet, l.Row, $"{found.Count} students are named {last.Trim()}, {rest.Trim()}; add a Student ID column to tell them apart.");
                    continue;
                }
                userId = found.SingleOrDefault()?.UserID;
            }
            if (userId == null)
            {
                result.NotInSystem++;
                Problem(l.Sheet, l.Row, l.RawId.Length > 0
                    ? $"Student ID {l.Id} is not in the system; row skipped."
                    : $"{(l.Last.Length > 0 ? $"{l.Last}, {l.First}" : l.FullName)} is not in the system; row skipped.");
                continue;
            }

            if (emailInFile.TryGetValue(l.Email, out var otherInFile) && otherInFile != userId)
            {
                Problem(l.Sheet, l.Row, $"{l.Email} is given to two students in the file ({nameOf[otherInFile]} and {nameOf[userId.Value]}); both skipped.");
                conflicted.Add(otherInFile);
                conflicted.Add(userId.Value);
                continue;
            }
            if (planned.TryGetValue(userId.Value, out var earlier) && earlier.Line.Email != l.Email)
            {
                Problem(l.Sheet, l.Row, $"{nameOf[userId.Value]} has two different emails in the file ({earlier.Line.Email} and {l.Email}); skipped.");
                conflicted.Add(userId.Value);
                continue;
            }
            emailInFile[l.Email] = userId.Value;
            planned[userId.Value] = (l, how);
        }

        // ── Decide and save ──
        var changes = new List<(Guid UserId, string Old, string New)>();
        foreach (var (userId, (l, how)) in planned)
        {
            if (conflicted.Contains(userId)) continue;
            var s = students.First(x => x.UserID == userId);
            var current = s.Email.ToLowerInvariant();
            if (current == l.Email)
            {
                result.AlreadySet++;
                continue;
            }
            if (!s.FirebaseUID.StartsWith(RecordsImportService.PendingUidPrefix))
            {
                Problem(l.Sheet, l.Row, $"{nameOf[userId]} has already signed in with {s.Email}; their email was not changed.");
                continue;
            }
            if (emailOwners.TryGetValue(l.Email, out var owner) && owner != userId)
            {
                var ownerName = nameOf.GetValueOrDefault(owner) ?? "another account";
                Problem(l.Sheet, l.Row, $"{l.Email} already belongs to {ownerName}; {nameOf[userId]} was skipped.");
                continue;
            }
            result.Emails++;
            if (current.Length > 0) result.Changed++;
            if (result.Rows.Count < MaxListedRows)
            {
                result.Rows.Add(new SchoolEmailsImportRowDto
                {
                    Sheet = l.Sheet, Row = l.Row, StudentId = s.StudentID ?? "", StudentName = nameOf[userId],
                    Email = l.Email, OldEmail = current.Length > 0 ? current : null, MatchedBy = how,
                });
            }
            changes.Add((userId, current, l.Email));
        }

        if (dryRun || changes.Count == 0) return result;

        var ids = changes.Select(c => c.UserId).ToList();
        var users = await _context.Users.Where(u => ids.Contains(u.UserID)).ToDictionaryAsync(u => u.UserID);
        foreach (var (userId, old, email) in changes)
        {
            users[userId].Email = email;
            result.Saved.Add((userId, old, email));
        }
        await _context.SaveChangesAsync();
        return result;
    }
}
