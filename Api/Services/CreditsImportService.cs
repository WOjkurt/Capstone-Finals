using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using Api.Common;
using Api.Domain.Enrollment;
using Api.DTOs.Credits;
using Api.DTOs.Records;
using Microsoft.EntityFrameworkCore;
using Microsoft.VisualBasic.FileIO;

namespace Api.Services;

public interface ICreditsImportService
{
    Task<CreditsImportResultDto> ImportAsync(Stream file, string fileName, bool dryRun, Guid callerId);
}

/// <summary>
/// Credits many subjects at once from an Excel (.xlsx) or CSV list, one row per credited subject.
/// Each row is checked with the same rules as Credit a subject in the app; nothing is saved on a dry run.
/// Rows already credited are skipped, so the same file can be imported again.
/// </summary>
public partial class CreditsImportService : ICreditsImportService
{
    public const int MaxListedRows = 300;

    private readonly AppDbContext _context;
    private readonly ICreditedSubjectService _credits;

    public CreditsImportService(AppDbContext context, ICreditedSubjectService credits)
    {
        _context = context;
        _credits = credits;
    }

    private sealed record InputRow(string Sheet, int Row, IReadOnlyList<string> Cells)
    {
        public string this[int i] => i >= 0 && i < Cells.Count ? Cells[i].Trim() : string.Empty;
    }

    /// <summary>Header text with only letters kept, e.g. "DBTC Subject Code" → "DBTCSUBJECTCODE".</summary>
    private static string Key(string header) => new(header.ToUpperInvariant().Where(char.IsAsciiLetter).ToArray());

    private static readonly string[] StudentIdHeaders = { "STUDENTID", "STUDENTNO", "STUDENTNUMBER", "IDNO", "IDNUMBER" };
    private static readonly string[] SubjectHeaders = { "DBTCSUBJECTCODE", "DBTCSUBJECT", "SUBJECTCODE", "SUBJECT", "SUBJECTS" };
    private static readonly string[] SchoolHeaders = { "SCHOOL", "OTHERSCHOOL", "SCHOOLNAME", "SOURCESCHOOL", "SCHOOLWHERETAKEN" };
    private static readonly string[] TheirCodeHeaders = { "THEIRSUBJECTCODE", "OTHERSCHOOLSUBJECTCODE", "SOURCESUBJECTCODE", "SUBJECTCODEATOTHERSCHOOL" };
    private static readonly string[] GradeHeaders = { "GRADE", "FINALGRADE", "FG" };
    private static readonly string[] SchoolYearHeaders = { "SCHOOLYEAR", "SY", "YEARTAKEN" };
    private static readonly string[] UnitsHeaders = { "UNITSCREDITED", "CREDITEDUNITS", "UNITS" };
    private static readonly string[] TypeHeaders = { "TYPE", "KIND", "CREDITTYPE" };
    private static readonly string[] TermHeaders = { "DBTCTERM", "TERM", "CROSSENROLLMENTTERM" };

    private static int Col(Dictionary<string, int> map, string[] names)
    {
        foreach (var n in names) if (map.TryGetValue(n, out var i)) return i;
        return -1;
    }

    internal static List<(string Sheet, List<(int Number, IReadOnlyList<string> Cells)> Rows)> ReadFile(Stream file, string fileName)
    {
        if (fileName.EndsWith(".csv", StringComparison.OrdinalIgnoreCase))
        {
            var rows = new List<(int, IReadOnlyList<string>)>();
            using var parser = new TextFieldParser(file, Encoding.UTF8) { TextFieldType = FieldType.Delimited, HasFieldsEnclosedInQuotes = true };
            parser.SetDelimiters(",");
            int n = 0;
            while (!parser.EndOfData)
            {
                n++;
                var fields = parser.ReadFields() ?? Array.Empty<string>();
                rows.Add((n, fields.Select(f => f.TrimStart('﻿')).ToList()));
            }
            return new() { ("CSV", rows) };
        }
        return XlsxReader.Read(file)
            .Select(s => (s.Name, s.Rows.Select(r => (r.Number, r.Cells)).ToList()))
            .ToList();
    }

    [GeneratedRegex(@"(\d{4})\s*-\s*(\d{4})")]
    private static partial Regex YearRegex();

    /// <summary>"1st Sem 2024-2025", "2024-2025 (2nd Sem)", "Summer 2024-2025" → (school year, semester).</summary>
    public static (string SchoolYear, int Semester)? TermOf(string text)
    {
        var y = YearRegex().Match(text);
        if (!y.Success) return null;
        var t = text.ToUpperInvariant();
        int? sem = t.Contains("SUMMER") || t.Contains("MIDYEAR") ? 3
            : Regex.IsMatch(t, @"\b(1ST|FIRST)\b") ? 1
            : Regex.IsMatch(t, @"\b(2ND|SECOND)\b") ? 2
            : null;
        return sem is { } s ? ($"{y.Groups[1].Value}-{y.Groups[2].Value}", s) : null;
    }

    /// <summary>Blank or "Transfer" → before DBTC; anything with "cross" → cross-enrolled. Null when not understood.</summary>
    public static int? KindOf(string text)
    {
        var k = Key(text);
        if (k.Length == 0 || k.StartsWith("TRANSFER") || k.StartsWith("BEFORE") || k.StartsWith("SHIFT") || k.StartsWith("PREVIOUS")) return CreditKinds.Transfer;
        if (k.StartsWith("CROSS")) return CreditKinds.CrossEnrollment;
        return null;
    }

    public async Task<CreditsImportResultDto> ImportAsync(Stream file, string fileName, bool dryRun, Guid callerId)
    {
        var result = new CreditsImportResultDto { DryRun = dryRun };
        void Problem(string sheet, int row, string message)
        {
            result.TotalProblems++;
            if (result.Problems.Count < 200) result.Problems.Add(new RecordsImportProblemDto { File = "Credits", Sheet = sheet, Row = row, Message = message });
        }

        // ── Find the header row of each sheet (the row with a Student ID column) ──
        var rows = new List<InputRow>();
        int cStudent = -1, cSubject = -1, cSchool = -1, cTheirCode = -1, cGrade = -1, cYear = -1, cUnits = -1, cType = -1, cTerm = -1;
        bool anyHeader = false;
        foreach (var (sheet, sheetRows) in ReadFile(file, fileName))
        {
            int headerIndex = -1;
            for (int i = 0; i < Math.Min(sheetRows.Count, 10) && headerIndex < 0; i++)
            {
                var map = new Dictionary<string, int>();
                for (int c = 0; c < sheetRows[i].Cells.Count; c++) map.TryAdd(Key(sheetRows[i].Cells[c]), c);
                if (Col(map, StudentIdHeaders) < 0 || Col(map, SubjectHeaders) < 0) continue;
                headerIndex = i;
                anyHeader = true;
                cStudent = Col(map, StudentIdHeaders);
                cSubject = Col(map, SubjectHeaders);
                cSchool = Col(map, SchoolHeaders);
                cTheirCode = Col(map, TheirCodeHeaders);
                cGrade = Col(map, GradeHeaders);
                cYear = Col(map, SchoolYearHeaders);
                cUnits = Col(map, UnitsHeaders);
                cType = Col(map, TypeHeaders);
                cTerm = Col(map, TermHeaders);
            }
            if (headerIndex < 0) continue;
            foreach (var r in sheetRows.Skip(headerIndex + 1))
            {
                if (r.Cells.All(string.IsNullOrWhiteSpace)) continue;
                var cells = r.Cells.ToList();
                // Collect in column order of this sheet's header, so later sheets may order columns differently.
                rows.Add(new InputRow(sheet, r.Number, new[]
                {
                    Cell(cells, cStudent), Cell(cells, cSubject), Cell(cells, cSchool), Cell(cells, cTheirCode), Cell(cells, cGrade),
                    Cell(cells, cYear), Cell(cells, cUnits), Cell(cells, cType), Cell(cells, cTerm)
                }));
            }
        }
        if (!anyHeader)
        {
            throw new InvalidDataException("No header row found. The first row needs at least the columns \"Student ID\" and \"DBTC Subject Code\".");
        }

        // ── Look up the students and subjects once ──
        var ids = rows.Select(r => StudentIdHelper.Normalize(XlsxReader.WholeNumberText(r[0])).Number)
            .Where(id => id != null).Cast<string>().Distinct().ToList();
        var students = await _context.UserDetails.AsNoTracking()
            .Where(d => d.StudentID != null && ids.Contains(d.StudentID) && d.User!.Role == Api.Auth.RoleUtils.Student)
            .ToDictionaryAsync(d => d.StudentID!);
        var programIds = students.Values.Where(s => s.ProgramID.HasValue).Select(s => s.ProgramID!.Value).Distinct().ToList();
        var subjects = await _context.Subjects.AsNoTracking().Where(s => programIds.Contains(s.ProgramID)).ToListAsync();
        var userIds = students.Values.Select(s => s.UserID).ToList();
        var existing = (await _context.CreditedSubjects.AsNoTracking().Where(c => userIds.Contains(c.UserID))
            .Select(c => new { c.UserID, c.SubjectID }).ToListAsync())
            .Select(c => (c.UserID, c.SubjectID)).ToHashSet();
        var terms = await _context.AcademicTerms.AsNoTracking().ToListAsync();

        var toAdd = new List<(CreditedSubject Credit, Subject Subject)>();
        var inFile = new Dictionary<(Guid, Guid), int>();
        var affected = new HashSet<Guid>();

        foreach (var row in rows)
        {
            var rawId = XlsxReader.WholeNumberText(row[0]);
            var idCheck = StudentIdHelper.Normalize(rawId);
            if (idCheck.Number == null)
            {
                Problem(row.Sheet, row.Row, idCheck.IsValid ? "No Student ID." : $"Student ID \"{rawId}\": {idCheck.ErrorMessage}");
                continue;
            }
            if (!students.TryGetValue(idCheck.Number, out var student))
            {
                Problem(row.Sheet, row.Row, $"No student with Student ID {idCheck.Number} in the system.");
                continue;
            }
            var code = row[1];
            if (code.Length == 0)
            {
                Problem(row.Sheet, row.Row, "No DBTC subject code.");
                continue;
            }
            if (!student.ProgramID.HasValue)
            {
                Problem(row.Sheet, row.Row, $"Student {idCheck.Number} has no program yet.");
                continue;
            }
            var key = RecordsImportService.CodeKey(code);
            var inProgram = subjects.Where(s => s.ProgramID == student.ProgramID && RecordsImportService.CodeKey(s.SubjectCode) == key).ToList();
            // The student's own curriculum first; otherwise the program's newest curriculum that has the code.
            var subject = inProgram.FirstOrDefault(s => student.CurriculumID != null && s.CurriculumID == student.CurriculumID)
                ?? inProgram.FirstOrDefault();
            if (subject == null)
            {
                Problem(row.Sheet, row.Row, $"{code} is not a subject of student {idCheck.Number}'s program.");
                continue;
            }

            if (existing.Contains((student.UserID, subject.SubjectID)))
            {
                result.AlreadyCredited++;
                continue;
            }
            if (inFile.TryGetValue((student.UserID, subject.SubjectID), out var firstRow))
            {
                Problem(row.Sheet, row.Row, $"{subject.SubjectCode} for student {idCheck.Number} is already on row {firstRow}.");
                continue;
            }

            var kind = KindOf(row[7]);
            if (kind == null)
            {
                Problem(row.Sheet, row.Row, $"Type \"{row[7]}\" is not understood. Write Transfer or Cross-enrollment.");
                continue;
            }
            Guid? termId = null;
            if (kind == CreditKinds.CrossEnrollment)
            {
                var t = TermOf(row[8]);
                var term = t is { } tt ? terms.FirstOrDefault(x => x.SchoolYear == tt.SchoolYear && x.Semester == tt.Semester) : null;
                if (term == null)
                {
                    Problem(row.Sheet, row.Row, row[8].Length == 0
                        ? "Cross-enrollment needs the DBTC term, e.g. \"1st Sem 2024-2025\"."
                        : $"DBTC term \"{row[8]}\" is not in the system.");
                    continue;
                }
                termId = term.TermID;
            }

            decimal fullUnits = subject.LecUnits + subject.LabUnits;
            decimal units = fullUnits;
            if (row[6].Length > 0 && !decimal.TryParse(row[6], NumberStyles.Number, CultureInfo.InvariantCulture, out units))
            {
                Problem(row.Sheet, row.Row, $"Units \"{row[6]}\" is not a number.");
                continue;
            }

            string? tooLong = row[2].Length > 200 ? "School" : row[3].Length > 50 ? "Their subject code" : row[4].Length > 20 ? "Grade" : row[5].Length > 20 ? "School year" : null;
            if (tooLong != null)
            {
                Problem(row.Sheet, row.Row, $"{tooLong} is too long.");
                continue;
            }

            var dto = new CreateCreditedSubjectDto
            {
                UserId = student.UserID,
                SubjectId = subject.SubjectID,
                SourceSchool = row[2],
                SourceSubjectCode = row[3],
                Grade = row[4],
                SchoolYear = row[5],
                CreditedUnits = units,
                Kind = kind.Value,
                TermId = termId,
            };
            try
            {
                var built = await _credits.BuildAsync(dto, callerId);
                toAdd.Add(built);
                inFile[(student.UserID, subject.SubjectID)] = row.Row;
                affected.Add(student.UserID);
                if (result.Rows.Count < MaxListedRows)
                {
                    result.Rows.Add(new CreditsImportRowDto
                    {
                        StudentId = idCheck.Number,
                        StudentName = $"{student.Lastname}, {student.Firstname}".Trim(' ', ','),
                        SubjectCode = subject.SubjectCode,
                        SubjectTitle = subject.SubjectTitle,
                        CreditedUnits = units,
                        Units = fullUnits,
                        SourceSchool = built.Credit.SourceSchool,
                        Grade = built.Credit.Grade,
                        Kind = kind.Value,
                    });
                }
            }
            catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
            {
                Problem(row.Sheet, row.Row, ex.Message);
            }
        }

        result.Credits = toAdd.Count;
        result.Students = affected.Count;
        if (!dryRun && toAdd.Count > 0)
        {
            _context.CreditedSubjects.AddRange(toAdd.Select(a => a.Credit));
            await _context.SaveChangesAsync();
            result.Added = toAdd;
        }
        return result;
    }

    private static string Cell(List<string> cells, int i) => i >= 0 && i < cells.Count ? cells[i] : string.Empty;
}
