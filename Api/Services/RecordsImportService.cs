using System.Globalization;
using System.Text.RegularExpressions;
using Api.Auth;
using Api.Common;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.Records;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public interface IRecordsImportService
{
    /// <summary>
    /// Imports old students and their grades from the registrar's Excel files. Students are matched by Student ID;
    /// new ones get a pending account that becomes theirs when they first sign in with their school email.
    /// Only the chosen school years of the grades file are imported. Re-running skips what is already there.
    /// </summary>
    Task<RecordsImportResultDto> ImportAsync(Stream gradesFile, Stream? studentsFile, IReadOnlyCollection<string> schoolYears,
        bool dryRun, bool releaseGrades, Guid callerUserId);
}

public partial class RecordsImportService : IRecordsImportService
{
    /// <summary>Students created by an import sign in later; until then their account has this placeholder.</summary>
    public const string PendingUidPrefix = "pending:";
    public const string ImportedClassName = "Old records";
    private const int MaxListedProblems = 200;

    private readonly AppDbContext _context;

    public RecordsImportService(AppDbContext context)
    {
        _context = context;
    }

    // ── What the files contain ─────────────────────────────────────────

    /// <summary>One grade line. <see cref="Program"/> is that row's course, which can differ from the student's
    /// current program (a shiftee's older subjects).</summary>
    private sealed record GradeRow(string Sheet, int Row, string SchoolYear, int Semester, string StudentId, string Code,
        string Midterm, string Final, int? Year, string? Program);

    private sealed class StudentInfo
    {
        public required string StudentId { get; init; }
        public string Lastname = "", Firstname = "", Middle = "";
        public bool NameFromGrades;
        public string? Sex;
        public string? ProgramCode;
        public int? YearLevel;
        public bool? IsRegular;
        public readonly List<GradeRow> Grades = new();
    }

    public sealed record SheetTerm(string SchoolYear, int Semester)
    {
        public int StartYear => int.Parse(SchoolYear[..4], CultureInfo.InvariantCulture);
        public int Order => StartYear * 10 + Semester;
    }

    [GeneratedRegex(@"(1ST|2ND|SUMMER)\D*?(\d{4})\s*-\s*(\d{4})", RegexOptions.IgnoreCase)]
    private static partial Regex SheetNameRegex();

    /// <summary>"1ST SEM_2025-2026" → (2025-2026, 1); "Summer_2024-2025" → (2024-2025, 3).</summary>
    public static SheetTerm? TermOfSheet(string sheetName)
    {
        var m = SheetNameRegex().Match(sheetName);
        if (!m.Success) return null;
        int semester = m.Groups[1].Value.ToUpperInvariant() switch { "1ST" => 1, "2ND" => 2, _ => 3 };
        return new SheetTerm($"{m.Groups[2].Value}-{m.Groups[3].Value}", semester);
    }

    /// <summary>Only letters and digits, upper case: "GEC 112B ELEC3" and "GEC 112B-Elec 3" are the same subject.</summary>
    public static string CodeKey(string code) =>
        new string(code.ToUpperInvariant().Where(char.IsAsciiLetterOrDigit).ToArray());

    /// <summary>The registrar's many spellings of a course, e.g. "BTVTEd /MT", "BSTE-MT", "BTVTED - MT" → BTVTED-MT.</summary>
    public static string? ProgramCodeOf(string course)
    {
        var c = course.ToUpperInvariant();
        var compact = new string(c.Where(char.IsAsciiLetterOrDigit).ToArray());
        if (compact.StartsWith("ABRE")) return "AB-REED";
        if (compact.StartsWith("BSIT")) return "BSIT";
        if (compact.StartsWith("BSME")) return "BSME";
        if (compact.StartsWith("BSIE") || compact.StartsWith("BSIIE")) return "BSIE";
        if (compact.StartsWith("BTVT") || compact.StartsWith("BSTE"))
        {
            var rest = compact[4..];
            if (rest.Contains("MECHANICAL") || rest.EndsWith("MT")) return "BTVTED-MT";
            if (rest.Contains("FURNITURE") || rest.EndsWith("FT")) return "BTVTED-FT";
            if (rest.Contains("ELECTRICAL") || rest.EndsWith("ET")) return "BTVTED-ET";
            return "BTVTED";
        }
        return null;
    }

    public static string NameCase(string raw)
    {
        var lower = Regex.Replace(raw.Trim(), @"\s+", " ").ToLower(new CultureInfo("en-PH"));
        var titled = new CultureInfo("en-PH").TextInfo.ToTitleCase(lower);
        return Regex.Replace(titled, @"\b(Ii|Iii|Iv)\b", m => m.Value.ToUpperInvariant());
    }

    public static string? SexOf(string raw) => raw.Trim().ToUpperInvariant() switch
    {
        "M" or "MALE" => "Male",
        "F" or "FEMALE" => "Female",
        _ => null,
    };

    private static int? YearOf(string raw) =>
        double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out var y) && y is >= 1 and <= 5 ? (int)y : null;

    private static Dictionary<string, int> HeaderMap(XlsxReader.Row header)
    {
        var map = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        for (int i = 0; i < header.Cells.Count; i++)
        {
            var key = Regex.Replace(header.Cells[i].ToUpperInvariant(), @"[^A-Z/]", "");
            if (key.Length > 0) map.TryAdd(key, i);
        }
        return map;
    }

    private static int Col(Dictionary<string, int> map, params string[] names)
    {
        foreach (var n in names) if (map.TryGetValue(n, out var i)) return i;
        return -1;
    }

    // ── Import ─────────────────────────────────────────────────────────

    public async Task<RecordsImportResultDto> ImportAsync(Stream gradesFile, Stream? studentsFile, IReadOnlyCollection<string> schoolYears,
        bool dryRun, bool releaseGrades, Guid callerUserId)
    {
        var result = new RecordsImportResultDto { DryRun = dryRun, GradesReleased = releaseGrades };
        void Problem(string file, string sheet, int row, string message)
        {
            result.TotalProblems++;
            if (result.Problems.Count < MaxListedProblems)
                result.Problems.Add(new RecordsImportProblemDto { File = file, Sheet = sheet, Row = row, Message = message });
        }

        var wanted = schoolYears.Select(s => s.Trim()).Where(s => s.Length > 0).ToHashSet();
        var students = new Dictionary<string, StudentInfo>();
        StudentInfo Student(string id) => students.TryGetValue(id, out var s) ? s : students[id] = new StudentInfo { StudentId = id };

        // 1. Grades file: one sheet per term.
        var gradeSheets = XlsxReader.Read(gradesFile)
            .Select(s => (Sheet: s, Term: TermOfSheet(s.Name)))
            .Where(x => x.Term != null)
            .ToList();
        result.SchoolYearsFound = gradeSheets.Select(x => x.Term!.SchoolYear).Distinct()
            .OrderByDescending(y => y, StringComparer.Ordinal).ToList();
        if (gradeSheets.Count == 0)
        {
            Problem("Grades", "", 0, "No sheet named like \"1ST SEM_2025-2026\", \"2ND SEM_2025-2026\" or \"SUMMER_2025-2026\" was found.");
            return result;
        }
        result.SchoolYearsImported = result.SchoolYearsFound.Where(wanted.Contains).ToList();

        foreach (var (sheet, term) in gradeSheets.Where(x => wanted.Contains(x.Term!.SchoolYear)).OrderBy(x => x.Term!.Order))
        {
            var headerIndex = sheet.Rows.FindIndex(r => r.Cells.Any(c => c.ToUpperInvariant().Contains("STUDENT")) &&
                                                       r.Cells.Any(c => c.ToUpperInvariant().StartsWith("SUBJECT")));
            if (headerIndex < 0)
            {
                Problem("Grades", sheet.Name, 0, "No header row with STUDENT NO. and SUBJECTS was found; sheet skipped.");
                continue;
            }
            var h = HeaderMap(sheet.Rows[headerIndex]);
            int cId = Col(h, "STUDENTNO", "STUDENTID"), cLast = Col(h, "LASTNAME"), cFirst = Col(h, "FIRSTNAME"),
                cMiddle = Col(h, "MIDDLENAME"), cSex = Col(h, "GENDER", "SEX"), cCourse = Col(h, "COURSE", "COURSE/MAJOR"),
                cYear = Col(h, "YEAR"), cCode = Col(h, "SUBJECTS", "SUBJECT", "SUBJECTCODE"), cMg = Col(h, "MG"), cFg = Col(h, "FG");
            if (cId < 0 || cCode < 0 || cFg < 0 || cCourse < 0)
            {
                Problem("Grades", sheet.Name, sheet.Rows[headerIndex].Number, "Columns STUDENT NO., COURSE, SUBJECTS and FG are needed; sheet skipped.");
                continue;
            }

            foreach (var row in sheet.Rows.Skip(headerIndex + 1))
            {
                var code = row[cCode];
                if (code.Length == 0) continue;
                var raw = XlsxReader.WholeNumberText(row[cId]);
                if (raw.ToUpperInvariant().Contains("STUDENT")) continue; // a repeated header row
                var id = StudentIdHelper.Normalize(raw);
                if (!id.IsValid || id.Number == null)
                {
                    Problem("Grades", sheet.Name, row.Number, raw.Length == 0 ? "No Student ID; row skipped." : $"Student ID \"{raw}\" is not valid; row skipped.");
                    continue;
                }
                var s = Student(id.Number);
                var program = ProgramCodeOf(row[cCourse]);
                if (program != null) s.ProgramCode = program;
                var year = YearOf(cYear >= 0 ? row[cYear] : "");
                if (year != null) s.YearLevel = year;
                if (cLast >= 0 && row[cLast].Length > 0)
                {
                    s.Lastname = row[cLast];
                    s.Firstname = cFirst >= 0 ? row[cFirst] : s.Firstname;
                    s.Middle = cMiddle >= 0 ? row[cMiddle] : s.Middle;
                    s.NameFromGrades = true;
                }
                if (cSex >= 0) s.Sex = SexOf(row[cSex]) ?? s.Sex;
                s.Grades.Add(new GradeRow(sheet.Name, row.Number, term!.SchoolYear, term.Semester, id.Number, code,
                    cMg >= 0 ? row[cMg] : "", row[cFg], year, program));
            }
        }

        // 2. Students file (optional): its newest sheet gives the current year level and regular/irregular status.
        if (studentsFile != null)
        {
            var latest = XlsxReader.Read(studentsFile)
                .Select(s => (Sheet: s, Term: TermOfSheet(s.Name)))
                .Where(x => x.Term != null)
                .OrderByDescending(x => x.Term!.Order)
                .FirstOrDefault();
            if (latest.Sheet == null)
            {
                Problem("Students", "", 0, "No sheet named like \"1st Sem_2026-2027\" was found; the students file was not used.");
            }
            else
            {
                result.Notes.Add($"Current year levels and regular/irregular status come from the students sheet \"{latest.Sheet.Name}\".");
                var headerIndex = latest.Sheet.Rows.FindIndex(r => r.Cells.Any(c => c.ToUpperInvariant().Contains("STUDENT ID")));
                var h = headerIndex >= 0 ? HeaderMap(latest.Sheet.Rows[headerIndex]) : new();
                int cId = Col(h, "STUDENTID", "STUDENTNO"), cName = Col(h, "STUDENTNAME"), cSex = Col(h, "GENDER", "SEX"),
                    cCourse = Col(h, "COURSE/MAJOR", "COURSE"), cYear = Col(h, "YEAR");
                if (cId < 0 || cCourse < 0)
                {
                    Problem("Students", latest.Sheet.Name, 0, "Columns STUDENT ID and COURSE/Major are needed; the students file was not used.");
                }
                else
                {
                    foreach (var row in latest.Sheet.Rows.Skip(headerIndex + 1))
                    {
                        var raw = XlsxReader.WholeNumberText(row[cId]);
                        if (raw.Length == 0 || raw.ToUpperInvariant().Contains("STUDENT")) continue; // blank or a repeated header row
                        var id = StudentIdHelper.Normalize(raw);
                        if (!id.IsValid || id.Number == null)
                        {
                            Problem("Students", latest.Sheet.Name, row.Number, $"Student ID \"{raw}\" is not valid; row skipped.");
                            continue;
                        }
                        var s = Student(id.Number);
                        s.ProgramCode = ProgramCodeOf(row[cCourse]) ?? s.ProgramCode;
                        s.YearLevel = YearOf(cYear >= 0 ? row[cYear] : "") ?? s.YearLevel;
                        if (cSex >= 0) s.Sex = SexOf(row[cSex]) ?? s.Sex;
                        var status = row.Cells.Select(c => c.ToUpperInvariant()).FirstOrDefault(c => c is "REGULAR" or "IRREGULAR");
                        if (status != null) s.IsRegular = status == "REGULAR";
                        if (!s.NameFromGrades && cName >= 0 && row[cName].Length > 0)
                        {
                            // "ABAPO, NATHANIEL CANARECIO": the middle name can't be told apart from a second first name.
                            var parts = row[cName].Split(',', 2);
                            s.Lastname = parts[0].Trim();
                            s.Firstname = parts.Length > 1 ? parts[1].Trim() : "";
                        }
                    }
                }
            }
        }

        // 3. Programs, curricula and subjects.
        var programs = await _context.AcademicPrograms.AsNoTracking().ToListAsync();
        var programByCode = programs.ToDictionary(p => p.ProgramCode.ToUpperInvariant());
        var curricula = await _context.Curricula.AsNoTracking().ToListAsync();
        var subjects = await _context.Subjects.AsNoTracking().ToListAsync();
        var subjectsByCurriculum = subjects.GroupBy(s => s.CurriculumID)
            .ToDictionary(g => g.Key, g => g.GroupBy(s => CodeKey(s.SubjectCode)).ToDictionary(x => x.Key, x => x.First()));
        var subjectsByProgram = subjects.GroupBy(s => s.ProgramID)
            .ToDictionary(g => g.Key, g => g.GroupBy(s => CodeKey(s.SubjectCode)).ToDictionary(x => x.Key, x => x.ToList()));

        var unknownPrograms = new Dictionary<string, int>();
        foreach (var s in students.Values.Where(s => s.ProgramCode == null || !programByCode.ContainsKey(s.ProgramCode)).ToList())
        {
            var label = s.ProgramCode ?? "(no course)";
            unknownPrograms[label] = unknownPrograms.GetValueOrDefault(label) + Math.Max(1, s.Grades.Count);
            students.Remove(s.StudentId);
        }
        foreach (var (code, rows) in unknownPrograms.OrderBy(x => x.Key))
        {
            Problem("", "", 0, code == "BTVTED"
                ? $"BTVTED without a major: {rows} row(s) skipped. The course must say MT, FT or ET."
                : $"Program {code} is not in Setup → Academic Programs: {rows} row(s) skipped. Add it first if these students should be imported.");
        }

        // 4. Existing students (by Student ID).
        var ids = students.Keys.ToList();
        var existing = await _context.UserDetails
            .Where(u => u.StudentID != null && ids.Contains(u.StudentID))
            .ToDictionaryAsync(u => u.StudentID!);
        var studentUserIds = existing.Values.Select(u => u.UserID).ToList();
        var existingLoads = (await _context.StudyLoads.AsNoTracking()
                .Where(sl => studentUserIds.Contains(sl.UserID) && sl.Class != null)
                .Select(sl => new { sl.UserID, sl.Class!.SubjectID, sl.Class.TermID })
                .ToListAsync())
            .Select(x => (x.UserID, x.SubjectID, x.TermID))
            .ToHashSet();

        // 5. Terms (created when missing) and the classes that hold imported grades.
        var terms = await _context.AcademicTerms.ToListAsync();
        AcademicTerm TermFor(string schoolYear, int semester)
        {
            var t = terms.FirstOrDefault(x => x.SchoolYear == schoolYear && x.Semester == semester);
            if (t != null) return t;
            t = new AcademicTerm { TermID = Guid.NewGuid(), SchoolYear = schoolYear, Semester = semester, IsActive = false };
            terms.Add(t);
            if (!dryRun) _context.AcademicTerms.Add(t);
            result.TermsCreated.Add(TermLabel.Format(schoolYear, semester));
            return t;
        }
        var classes = await _context.Classes.Where(c => c.ClassName == ImportedClassName).ToListAsync();
        Class ClassFor(Subject subject, AcademicTerm term)
        {
            var c = classes.FirstOrDefault(x => x.SubjectID == subject.SubjectID && x.TermID == term.TermID);
            if (c != null) return c;
            c = new Class
            {
                ClassID = Guid.NewGuid(), SubjectID = subject.SubjectID, TermID = term.TermID, ClassName = ImportedClassName,
                CreatedAt = DateTime.UtcNow, CreatedByUserID = callerUserId,
            };
            classes.Add(c);
            if (!dryRun) _context.Classes.Add(c);
            return c;
        }

        var activeStartYear = CurriculumService.StartYear(terms.FirstOrDefault(t => t.IsActive)?.SchoolYear)
                              ?? gradeSheets.Max(x => x.Term!.StartYear);
        var unknownSubjects = new Dictionary<(string Program, string Code), int>();
        var namesToCheck = 0;
        var clearances = new HashSet<(Guid UserId, Guid TermId)>();

        foreach (var s in students.Values.OrderBy(s => s.StudentId))
        {
            var program = programByCode[s.ProgramCode!];
            var programCurricula = curricula.Where(c => c.ProgramID == program.ProgramID).ToList();
            Guid userId;
            Guid? curriculumId;

            if (existing.TryGetValue(s.StudentId, out var details))
            {
                result.ExistingStudents++;
                userId = details.UserID;
                curriculumId = details.CurriculumID;
                if (details.ProgramID != program.ProgramID)
                {
                    result.Notes.Add($"Student ID {s.StudentId} ({details.Firstname} {details.Lastname}) is {program.ProgramCode} in the file but has another program in the system; the program was not changed.");
                }
            }
            else
            {
                // The curriculum whose codes match their grades best; otherwise the one of their batch.
                var keys = s.Grades.Select(g => CodeKey(g.Code)).ToHashSet();
                var best = programCurricula
                    .Select(c => (Curriculum: c, Hits: subjectsByCurriculum.TryGetValue(c.CurriculumID, out var d) ? keys.Count(d.ContainsKey) : 0))
                    .OrderByDescending(x => x.Hits).ThenByDescending(x => x.Curriculum.EffectiveFromYear)
                    .FirstOrDefault();
                curriculumId = best.Hits > 0
                    ? best.Curriculum.CurriculumID
                    : CurriculumService.ForBatch(programCurricula, BatchYear(s, activeStartYear))?.CurriculumID;

                result.NewStudents++;
                result.StudentsPerProgram[program.ProgramCode] = result.StudentsPerProgram.GetValueOrDefault(program.ProgramCode) + 1;
                var curriculumLabel = $"{program.ProgramCode} {programCurricula.FirstOrDefault(c => c.CurriculumID == curriculumId)?.Name ?? "(no curriculum)"}";
                result.StudentsPerCurriculum[curriculumLabel] = result.StudentsPerCurriculum.GetValueOrDefault(curriculumLabel) + 1;
                if (!s.NameFromGrades) namesToCheck++;

                userId = Guid.NewGuid();
                if (!dryRun)
                {
                    _context.Users.Add(new User
                    {
                        UserID = userId,
                        FirebaseUID = PendingUidPrefix + userId.ToString("N"),
                        Email = string.Empty,
                        Role = RoleUtils.Student,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow,
                    });
                    _context.UserDetails.Add(new UserDetails
                    {
                        UserDetailID = Guid.NewGuid(),
                        UserID = userId,
                        Firstname = NameCase(s.Firstname.Length > 0 ? s.Firstname : "-"),
                        Lastname = NameCase(s.Lastname.Length > 0 ? s.Lastname : "-"),
                        StudentID = s.StudentId,
                        ProgramID = program.ProgramID,
                        CurriculumID = curriculumId,
                        YearLevel = s.YearLevel,
                        StudentType = 2,   // Old student
                        StudentStatus = 1, // Enrolled
                        IsRegular = s.IsRegular ?? true,
                        IrregularSince = s.IsRegular == false ? DateTime.UtcNow : null,
                    });
                    if (s.Sex != null || s.Middle.Length > 0)
                    {
                        _context.StudentPersonalDetails.Add(new StudentPersonalDetails
                        {
                            UserID = userId,
                            MiddleName = s.Middle.Length > 0 ? NameCase(s.Middle) : null,
                            Sex = s.Sex,
                            UpdatedByUserID = callerUserId,
                            UpdatedAt = DateTime.UtcNow,
                        });
                    }
                }
            }

            var mySubjects = curriculumId is { } cid && subjectsByCurriculum.TryGetValue(cid, out var dict) ? dict : new();
            var programSubjects = subjectsByProgram.GetValueOrDefault(program.ProgramID) ?? new();
            foreach (var g in s.Grades)
            {
                // The student's curriculum, then their program, then the program written on that row
                // (e.g. a shiftee's subjects from their old program). "NSTP 01" also finds "NSTP 01A".
                var key = CodeKey(g.Code);
                var rowProgram = g.Program != null && programByCode.TryGetValue(g.Program, out var rp) ? rp : null;
                var rowSubjects = rowProgram != null ? subjectsByProgram.GetValueOrDefault(rowProgram.ProgramID) : null;
                var subject = mySubjects.GetValueOrDefault(key) ?? mySubjects.GetValueOrDefault(key + "A")
                              ?? programSubjects.GetValueOrDefault(key)?.FirstOrDefault()
                              ?? programSubjects.GetValueOrDefault(key + "A")?.FirstOrDefault()
                              ?? rowSubjects?.GetValueOrDefault(key)?.FirstOrDefault()
                              ?? rowSubjects?.GetValueOrDefault(key + "A")?.FirstOrDefault();
                if (subject == null)
                {
                    var k = (program.ProgramCode, g.Code.ToUpperInvariant());
                    unknownSubjects[k] = unknownSubjects.GetValueOrDefault(k) + 1;
                    continue;
                }

                var final = g.Final.Trim().ToUpperInvariant();
                decimal? finalGrade = null;
                bool dropped = final is "DR" or "DRP" or "DROPPED" or "W" or "WITHDRAWN";
                bool noGrade = final is "" or "NA" or "N/A" or "NG" or "INC";
                if (!dropped && !noGrade)
                {
                    if (!decimal.TryParse(final, NumberStyles.Number, CultureInfo.InvariantCulture, out var fg) || !GradeScale.IsValid(fg))
                    {
                        Problem("Grades", g.Sheet, g.Row, $"Final grade \"{g.Final}\" of {g.Code} (Student ID {g.StudentId}) is not a valid grade; row skipped.");
                        continue;
                    }
                    finalGrade = fg;
                }

                var term = TermFor(g.SchoolYear, g.Semester);
                if (existingLoads.Contains((userId, subject.SubjectID, term.TermID)))
                {
                    result.AlreadyImported++;
                    continue;
                }
                existingLoads.Add((userId, subject.SubjectID, term.TermID));

                if (dropped) result.Dropped++;
                else if (finalGrade == null) result.NoGradeYet++;
                else if (GradeScale.Remarks(finalGrade.Value) == 1) result.GradesPassed++;
                else result.GradesFailed++;
                if (finalGrade != null) clearances.Add((userId, term.TermID));

                if (dryRun) continue;
                var load = new StudyLoad
                {
                    StudyLoadID = Guid.NewGuid(),
                    UserID = userId,
                    ClassID = ClassFor(subject, term).ClassID,
                    LoadStatus = dropped ? StudyLoadStatus.Dropped : StudyLoadStatus.Enrolled,
                    CreatedAt = DateTime.UtcNow,
                    CreatedByUserID = callerUserId,
                };
                _context.StudyLoads.Add(load);
                if (finalGrade != null)
                {
                    decimal? midterm = decimal.TryParse(g.Midterm, NumberStyles.Number, CultureInfo.InvariantCulture, out var mg) && GradeScale.IsValid(mg)
                        ? mg : null;
                    _context.Grades.Add(new Grade
                    {
                        GradeID = Guid.NewGuid(),
                        StudyLoadID = load.StudyLoadID,
                        MidtermGrade = midterm,
                        FinalGrade = finalGrade,
                        Remarks = GradeScale.Remarks(finalGrade.Value),
                        SubmittedByUserID = callerUserId,
                        DateSubmitted = DateTime.UtcNow,
                    });
                }
            }
        }

        // Listed once per code; every skipped row still counts as a problem.
        foreach (var ((program, code), count) in unknownSubjects.OrderBy(x => x.Key.Program).ThenBy(x => x.Key.Code))
        {
            Problem("Grades", "", 0, $"{program}: subject code {code} is not in any {program} curriculum: {count} row(s) skipped.");
            result.TotalProblems += count - 1;
        }
        if (namesToCheck > 0)
        {
            result.Notes.Add($"{namesToCheck} student(s) appear only in the students file, so their first and middle names are together in First name. Check them on their profile.");
        }
        if (result.NewStudents > 0)
        {
            result.Notes.Add("New students can't sign in until their school email is added on their profile.");
        }

        // 6. Release the imported grades (needed for online enrollment, which requires the last term to be cleared).
        if (releaseGrades && clearances.Count > 0 && !dryRun)
        {
            var termIds = clearances.Select(c => c.TermId).Distinct().ToList();
            var userIds = clearances.Select(c => c.UserId).Distinct().ToList();
            var current = await _context.GradeClearances
                .Where(c => termIds.Contains(c.TermID) && userIds.Contains(c.UserID))
                .ToListAsync();
            foreach (var (u, t) in clearances)
            {
                var row = current.FirstOrDefault(c => c.UserID == u && c.TermID == t);
                if (row == null)
                {
                    _context.GradeClearances.Add(new GradeClearance
                    {
                        ClearanceID = Guid.NewGuid(), UserID = u, TermID = t, IsCleared = true,
                        ClearedByUserID = callerUserId, ClearedAt = DateTime.UtcNow,
                    });
                }
                else if (!row.IsCleared)
                {
                    row.IsCleared = true;
                    row.ClearedByUserID = callerUserId;
                    row.ClearedAt = DateTime.UtcNow;
                }
            }
        }

        if (!dryRun)
        {
            await using var tx = _context.Database.IsRelational() ? await _context.Database.BeginTransactionAsync() : null;
            await _context.SaveChangesAsync();
            if (tx != null) await tx.CommitAsync();
        }
        return result;
    }

    /// <summary>DBTC IDs start with the entry year (25060208 → 2025); otherwise work it out from the year level.</summary>
    private static int BatchYear(StudentInfo s, int termStartYear)
    {
        if (s.StudentId.Length == 8 && int.TryParse(s.StudentId[..2], out var yy))
        {
            var year = 2000 + yy;
            if (year >= 2000 && year <= termStartYear) return year;
        }
        return CurriculumService.BatchYear(termStartYear, s.YearLevel);
    }
}
