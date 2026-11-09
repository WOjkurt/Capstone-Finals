using System.Globalization;
using System.Text;
using Api.Constants;
using Api.Data;
using Api.Domain.Enrollment;
using Api.DTOs.Curriculum;
using Microsoft.EntityFrameworkCore;
using Microsoft.VisualBasic.FileIO;

namespace Api.Services;

public class CurriculumImportService : ICurriculumImportService
{
    private static readonly string[] RequiredHeaders = new[]
    {
        "program", "code", "title", "units", "lec_units", "lab_units",
        "lec_hours", "lab_hours", "year", "semester", "prerequisites",
        "corequisites", "standing_year"
    };

    private readonly AppDbContext _context;

    public CurriculumImportService(AppDbContext context)
    {
        _context = context;
    }

    public async Task<CurriculumImportResponseDto> ImportAsync(
        Stream csvStream,
        string fileName,
        long fileLength,
        bool dryRun,
        bool updateExisting,
        Guid callerUserId,
        Guid? curriculumId = null)
    {
        var warnings = new List<CurriculumImportFindingDto>();
        var errors = new List<CurriculumImportFindingDto>();

        // ── 1. File checks ──────────────────────────────────────────────────────────
        if (fileLength > 1024 * 1024)
        {
            errors.Add(new CurriculumImportFindingDto
            {
                Row = 0,
                Code = "",
                Message = $"File size ({fileLength} bytes) exceeds maximum limit of 1 MB."
            });
            return BuildResponse(dryRun, "", 0, 0, 0, 0, 0, 0, 0, warnings, errors);
        }

        if (string.IsNullOrWhiteSpace(fileName) || !fileName.EndsWith(".csv", StringComparison.OrdinalIgnoreCase))
        {
            errors.Add(new CurriculumImportFindingDto
            {
                Row = 0,
                Code = "",
                Message = "File must have a .csv extension."
            });
            return BuildResponse(dryRun, "", 0, 0, 0, 0, 0, 0, 0, warnings, errors);
        }

        // ── 2. Parse CSV with TextFieldParser ───────────────────────────────────────
        using var reader = new StreamReader(csvStream, Encoding.UTF8, detectEncodingFromByteOrderMarks: true, bufferSize: 1024, leaveOpen: true);
        using var parser = new TextFieldParser(reader);
        parser.TextFieldType = FieldType.Delimited;
        parser.SetDelimiters(",");
        parser.HasFieldsEnclosedInQuotes = true;
        parser.TrimWhiteSpace = true;

        if (parser.EndOfData)
        {
            errors.Add(new CurriculumImportFindingDto
            {
                Row = 0,
                Code = "",
                Message = "CSV file is empty."
            });
            return BuildResponse(dryRun, "", 0, 0, 0, 0, 0, 0, 0, warnings, errors);
        }

        string[]? rawHeaders;
        try
        {
            rawHeaders = parser.ReadFields();
        }
        catch (MalformedLineException ex)
        {
            errors.Add(new CurriculumImportFindingDto
            {
                Row = 1,
                Code = "",
                Message = $"Malformed CSV header: {ex.Message}"
            });
            return BuildResponse(dryRun, "", 0, 0, 0, 0, 0, 0, 0, warnings, errors);
        }

        if (rawHeaders == null || rawHeaders.Length == 0)
        {
            errors.Add(new CurriculumImportFindingDto
            {
                Row = 1,
                Code = "",
                Message = "CSV header row is missing or empty."
            });
            return BuildResponse(dryRun, "", 0, 0, 0, 0, 0, 0, 0, warnings, errors);
        }

        var headerMap = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        for (int i = 0; i < rawHeaders.Length; i++)
        {
            var clean = rawHeaders[i]?.Trim('\uFEFF', ' ', '\r', '\n', '\t') ?? "";
            if (!string.IsNullOrEmpty(clean))
            {
                headerMap[clean] = i;
            }
        }

        var missingHeaders = RequiredHeaders.Where(req => !headerMap.ContainsKey(req)).ToList();
        if (missingHeaders.Count > 0)
        {
            errors.Add(new CurriculumImportFindingDto
            {
                Row = 1,
                Code = "",
                Message = $"Missing required CSV header(s): {string.Join(", ", missingHeaders)}."
            });
            return BuildResponse(dryRun, "", 0, 0, 0, 0, 0, 0, 0, warnings, errors);
        }

        // ── 3. Parse and Validate Data Rows ─────────────────────────────────────────
        var parsedRows = new List<CsvRowData>();
        int physicalRowNumber = 1;

        while (!parser.EndOfData)
        {
            physicalRowNumber++;
            string[]? fields;
            try
            {
                fields = parser.ReadFields();
            }
            catch (MalformedLineException ex)
            {
                errors.Add(new CurriculumImportFindingDto
                {
                    Row = physicalRowNumber,
                    Code = "",
                    Message = $"Malformed CSV on row {physicalRowNumber}: {ex.Message}"
                });
                continue;
            }

            if (fields == null || fields.Length == 0 || fields.All(string.IsNullOrWhiteSpace))
            {
                continue; // skip blank lines
            }

            if (parsedRows.Count >= 2000)
            {
                errors.Add(new CurriculumImportFindingDto
                {
                    Row = physicalRowNumber,
                    Code = "",
                    Message = "File exceeds maximum limit of 2000 rows."
                });
                break;
            }

            string GetField(string name)
            {
                if (headerMap.TryGetValue(name, out var idx) && idx < fields.Length)
                {
                    return fields[idx]?.Trim() ?? "";
                }
                return "";
            }

            var rawProgram = GetField("program");
            var rawCode = GetField("code");
            var rawTitle = GetField("title");
            var rawUnits = GetField("units");
            var rawLecUnits = GetField("lec_units");
            var rawLabUnits = GetField("lab_units");
            var rawLecHours = GetField("lec_hours");
            var rawLabHours = GetField("lab_hours");
            var rawYear = GetField("year");
            var rawSemester = GetField("semester");
            var rawPrereqs = GetField("prerequisites");
            var rawCoreqs = GetField("corequisites");
            var rawStanding = GetField("standing_year");
            bool hasMinorColumn = headerMap.ContainsKey("minor");
            var rawMinor = GetField("minor");

            var normalizedCode = SubjectService.NormalizeSubjectCode(rawCode);

            // Program
            if (string.IsNullOrWhiteSpace(rawProgram))
            {
                errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = "program is required." });
            }

            // Code
            if (string.IsNullOrWhiteSpace(rawCode))
            {
                errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = "", Message = "code is required." });
            }
            else if (normalizedCode.Length > 50)
            {
                errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = "code exceeds maximum length of 50 characters." });
            }

            // Title
            if (string.IsNullOrWhiteSpace(rawTitle))
            {
                errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = "title is required." });
            }
            else if (rawTitle.Length > 200)
            {
                errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = "title exceeds maximum length of 200 characters." });
            }

            // Units (lec_units, lab_units, units)
            bool unitsOk = decimal.TryParse(rawUnits, NumberStyles.Any, CultureInfo.InvariantCulture, out var units);
            bool lecUnitsOk = decimal.TryParse(rawLecUnits, NumberStyles.Any, CultureInfo.InvariantCulture, out var lecUnits);
            bool labUnitsOk = decimal.TryParse(rawLabUnits, NumberStyles.Any, CultureInfo.InvariantCulture, out var labUnits);

            if (!unitsOk || !lecUnitsOk || !labUnitsOk)
            {
                errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = "Invalid numeric format for units, lec_units, or lab_units." });
            }
            else
            {
                if (units < 0 || lecUnits < 0 || labUnits < 0)
                {
                    errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = "Units cannot be negative." });
                }

                if (units != lecUnits + labUnits)
                {
                    errors.Add(new CurriculumImportFindingDto
                    {
                        Row = physicalRowNumber,
                        Code = normalizedCode,
                        Message = $"units ({units}) must equal lec_units ({lecUnits}) + lab_units ({labUnits})."
                    });
                }
            }

            // Hours (lec_hours, lab_hours)
            bool lecHoursOk = decimal.TryParse(rawLecHours, NumberStyles.Any, CultureInfo.InvariantCulture, out var lecHours);
            bool labHoursOk = decimal.TryParse(rawLabHours, NumberStyles.Any, CultureInfo.InvariantCulture, out var labHours);

            if (!lecHoursOk || !labHoursOk)
            {
                errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = "Invalid numeric format for lec_hours or lab_hours." });
            }
            else if (lecHours < 0 || labHours < 0)
            {
                errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = "Hours cannot be negative." });
            }

            // Year
            bool yearOk = int.TryParse(rawYear, out var year);
            if (!yearOk || year < 1 || year > 4)
            {
                errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = $"year must be between 1 and 4 (found '{rawYear}')." });
            }

            // Semester
            bool semOk = int.TryParse(rawSemester, out var semester);
            if (!semOk || semester < 1 || semester > 3)
            {
                errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = $"semester must be between 1 and 3 (found '{rawSemester}')." });
            }

            // Standing Year
            int? standingYear = null;
            if (!string.IsNullOrWhiteSpace(rawStanding))
            {
                if (int.TryParse(rawStanding, out var sy) && sy >= 1 && sy <= 4)
                {
                    standingYear = sy;
                }
                else
                {
                    errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = $"standing_year must be between 1 and 4 or blank (found '{rawStanding}')." });
                }
            }

            // Minor (optional column). Without the column the flag is left alone.
            bool? isMinor = null;
            if (hasMinorColumn)
            {
                switch (rawMinor.ToLowerInvariant())
                {
                    case "yes": case "y": case "true": case "1":
                        isMinor = true;
                        break;
                    case "no": case "n": case "false": case "0": case "":
                        isMinor = false;
                        break;
                    default:
                        errors.Add(new CurriculumImportFindingDto { Row = physicalRowNumber, Code = normalizedCode, Message = $"minor must be yes, no or blank (found '{rawMinor}')." });
                        break;
                }
            }

            // Prerequisites & Corequisites parsing
            var prereqCodes = rawPrereqs
                .Split(';', StringSplitOptions.RemoveEmptyEntries)
                .Select(s => SubjectService.NormalizeSubjectCode(s))
                .Where(s => !string.IsNullOrEmpty(s))
                .ToList();

            var coreqCodes = rawCoreqs
                .Split(';', StringSplitOptions.RemoveEmptyEntries)
                .Select(s => SubjectService.NormalizeSubjectCode(s))
                .Where(s => !string.IsNullOrEmpty(s))
                .ToList();

            parsedRows.Add(new CsvRowData
            {
                RowNumber = physicalRowNumber,
                Program = rawProgram,
                RawCode = rawCode,
                NormalizedCode = normalizedCode,
                Title = rawTitle,
                Units = units,
                LecUnits = lecUnits,
                LabUnits = labUnits,
                LecHours = lecHours,
                LabHours = labHours,
                Year = year,
                Semester = semester,
                StandingYear = standingYear,
                IsMinor = isMinor,
                Prerequisites = prereqCodes,
                Corequisites = coreqCodes
            });
        }

        // ── 4. Program Consistency and Database Lookup ──────────────────────────────
        var programCodes = parsedRows
            .Select(r => r.Program.Trim())
            .Where(p => !string.IsNullOrEmpty(p))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        string targetProgramCode = programCodes.FirstOrDefault() ?? "";

        if (programCodes.Count > 1)
        {
            foreach (var r in parsedRows.Where(r => !r.Program.Equals(targetProgramCode, StringComparison.OrdinalIgnoreCase)))
            {
                errors.Add(new CurriculumImportFindingDto
                {
                    Row = r.RowNumber,
                    Code = r.NormalizedCode,
                    Message = $"Row has program '{r.Program}' which does not match expected program '{targetProgramCode}'. All rows must have the same program."
                });
            }
        }

        var programEntity = !string.IsNullOrEmpty(targetProgramCode)
            ? await _context.AcademicPrograms.FirstOrDefaultAsync(p => p.ProgramCode.ToUpper() == targetProgramCode.ToUpper())
            : null;

        if (!string.IsNullOrEmpty(targetProgramCode) && programEntity == null)
        {
            var knownCodes = await _context.AcademicPrograms.Select(p => p.ProgramCode).OrderBy(c => c).ToListAsync();
            errors.Add(new CurriculumImportFindingDto
            {
                Row = 1,
                Code = "",
                Message = $"Program '{targetProgramCode}' does not exist. Known programs: {string.Join(", ", knownCodes)}."
            });
        }

        // The curriculum to import into: the one asked for, else the program's newest (made on apply if none).
        Curriculum? curriculumEntity = null;
        if (programEntity != null)
        {
            if (curriculumId is { } wantedId)
            {
                curriculumEntity = await _context.Curricula.AsNoTracking().FirstOrDefaultAsync(c => c.CurriculumID == wantedId);
                if (curriculumEntity == null || curriculumEntity.ProgramID != programEntity.ProgramID)
                {
                    errors.Add(new CurriculumImportFindingDto
                    {
                        Row = 0,
                        Code = "",
                        Message = curriculumEntity == null
                            ? "The chosen curriculum was not found."
                            : $"The chosen curriculum is not a {programEntity.ProgramCode} curriculum."
                    });
                    curriculumEntity = null;
                }
            }
            else
            {
                curriculumEntity = await _context.Curricula.AsNoTracking()
                    .Where(c => c.ProgramID == programEntity.ProgramID)
                    .OrderByDescending(c => c.EffectiveFromYear)
                    .FirstOrDefaultAsync();
            }
        }
        Guid? targetCurriculumId = curriculumEntity?.CurriculumID;

        // ── 5. Duplicate Codes in File ──────────────────────────────────────────────
        var seenCodes = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        foreach (var row in parsedRows.Where(r => !string.IsNullOrEmpty(r.NormalizedCode)))
        {
            if (seenCodes.TryGetValue(row.NormalizedCode, out var prevRow))
            {
                errors.Add(new CurriculumImportFindingDto
                {
                    Row = row.RowNumber,
                    Code = row.NormalizedCode,
                    Message = $"Duplicate subject code '{row.NormalizedCode}' inside file (previously seen on row {prevRow})."
                });
            }
            else
            {
                seenCodes[row.NormalizedCode] = row.RowNumber;
            }
        }

        // ── 6. Requisite Rules & Cycle Detection ───────────────────────────────────
        // A program without curricula yet (older data): its subjects are matched by program as before.
        var dbSubjects = targetCurriculumId != null
            ? await _context.Subjects.Where(s => s.CurriculumID == targetCurriculumId).ToListAsync()
            : programEntity != null
                ? await _context.Subjects.Where(s => s.ProgramID == programEntity.ProgramID).ToListAsync()
                : new List<Subject>();

        var dbSubjectIds = dbSubjects.Select(s => s.SubjectID).ToList();
        var dbSubjectMap = dbSubjects.ToDictionary(s => SubjectService.NormalizeSubjectCode(s.SubjectCode), StringComparer.OrdinalIgnoreCase);
        var fileSubjectMap = parsedRows
            .Where(r => !string.IsNullOrEmpty(r.NormalizedCode))
            .GroupBy(r => r.NormalizedCode, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

        // Load existing prerequisite edges (type 0 only) for this program
        var dbPrereqs = dbSubjectIds.Count > 0
            ? await _context.SubjectPrerequisites
                .Include(sp => sp.Subject)
                .Include(sp => sp.PrerequisiteSubject)
                .Where(sp => dbSubjectIds.Contains(sp.SubjectID) && sp.RequisiteType == RequisiteTypeConstants.Prerequisite)
                .ToListAsync()
            : new List<SubjectPrerequisite>();

        var prereqGraph = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
        foreach (var sp in dbPrereqs)
        {
            if (sp.Subject != null && sp.PrerequisiteSubject != null)
            {
                var sCode = SubjectService.NormalizeSubjectCode(sp.Subject.SubjectCode);
                var pCode = SubjectService.NormalizeSubjectCode(sp.PrerequisiteSubject.SubjectCode);
                if (!prereqGraph.TryGetValue(sCode, out var set))
                {
                    set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                    prereqGraph[sCode] = set;
                }
                set.Add(pCode);
            }
        }

        foreach (var row in parsedRows)
        {
            var pSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var cSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            // Self-links & duplicate in cell checks
            foreach (var p in row.Prerequisites)
            {
                if (p.Equals(row.NormalizedCode, StringComparison.OrdinalIgnoreCase))
                {
                    errors.Add(new CurriculumImportFindingDto
                    {
                        Row = row.RowNumber,
                        Code = row.NormalizedCode,
                        Message = $"Subject '{row.NormalizedCode}' cannot have itself as a prerequisite."
                    });
                }

                if (!pSet.Add(p))
                {
                    errors.Add(new CurriculumImportFindingDto
                    {
                        Row = row.RowNumber,
                        Code = row.NormalizedCode,
                        Message = $"Subject '{row.NormalizedCode}' has duplicate prerequisite '{p}' in cell."
                    });
                }
            }

            foreach (var c in row.Corequisites)
            {
                if (c.Equals(row.NormalizedCode, StringComparison.OrdinalIgnoreCase))
                {
                    errors.Add(new CurriculumImportFindingDto
                    {
                        Row = row.RowNumber,
                        Code = row.NormalizedCode,
                        Message = $"Subject '{row.NormalizedCode}' cannot have itself as a corequisite."
                    });
                }

                if (!cSet.Add(c))
                {
                    errors.Add(new CurriculumImportFindingDto
                    {
                        Row = row.RowNumber,
                        Code = row.NormalizedCode,
                        Message = $"Subject '{row.NormalizedCode}' has duplicate corequisite '{c}' in cell."
                    });
                }
            }

            // Both columns check
            foreach (var p in pSet)
            {
                if (cSet.Contains(p))
                {
                    errors.Add(new CurriculumImportFindingDto
                    {
                        Row = row.RowNumber,
                        Code = row.NormalizedCode,
                        Message = $"Subject '{row.NormalizedCode}' lists '{p}' as both a prerequisite and corequisite."
                    });
                }
            }

            // Existence check
            foreach (var p in pSet)
            {
                if (!fileSubjectMap.ContainsKey(p) && !dbSubjectMap.ContainsKey(p))
                {
                    errors.Add(new CurriculumImportFindingDto
                    {
                        Row = row.RowNumber,
                        Code = row.NormalizedCode,
                        Message = $"Prerequisite '{p}' does not exist in the curriculum file or database for program '{targetProgramCode}'."
                    });
                }
            }

            foreach (var c in cSet)
            {
                if (!fileSubjectMap.ContainsKey(c) && !dbSubjectMap.ContainsKey(c))
                {
                    errors.Add(new CurriculumImportFindingDto
                    {
                        Row = row.RowNumber,
                        Code = row.NormalizedCode,
                        Message = $"Corequisite '{c}' does not exist in the curriculum file or database for program '{targetProgramCode}'."
                    });
                }
            }

            // Cycle detection among prerequisites (type 0 only)
            foreach (var p in pSet)
            {
                if (fileSubjectMap.ContainsKey(p) || dbSubjectMap.ContainsKey(p))
                {
                    if (CanReach(p, row.NormalizedCode, prereqGraph))
                    {
                        errors.Add(new CurriculumImportFindingDto
                        {
                            Row = row.RowNumber,
                            Code = row.NormalizedCode,
                            Message = $"Circular prerequisite detected: '{p}' already requires '{row.NormalizedCode}' directly or indirectly."
                        });
                    }
                    else
                    {
                        if (!prereqGraph.TryGetValue(row.NormalizedCode, out var set))
                        {
                            set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                            prereqGraph[row.NormalizedCode] = set;
                        }
                        set.Add(p);
                    }
                }
            }

            // Warnings: scheduling comparison
            (int Year, int Semester)? GetYearSem(string code)
            {
                if (fileSubjectMap.TryGetValue(code, out var f)) return (f.Year, f.Semester);
                if (dbSubjectMap.TryGetValue(code, out var d)) return (d.YearLevel, d.DefaultSemester);
                return null;
            }

            foreach (var p in pSet)
            {
                var ys = GetYearSem(p);
                if (ys.HasValue)
                {
                    if (ys.Value.Year > row.Year || (ys.Value.Year == row.Year && ys.Value.Semester >= row.Semester))
                    {
                        warnings.Add(new CurriculumImportFindingDto
                        {
                            Row = row.RowNumber,
                            Code = row.NormalizedCode,
                            Message = $"Prerequisite '{p}' is scheduled in Year {ys.Value.Year} Semester {ys.Value.Semester}, which is not before Year {row.Year} Semester {row.Semester}."
                        });
                    }
                }
            }

            foreach (var c in cSet)
            {
                var ys = GetYearSem(c);
                if (ys.HasValue)
                {
                    if (ys.Value.Year != row.Year || ys.Value.Semester != row.Semester)
                    {
                        warnings.Add(new CurriculumImportFindingDto
                        {
                            Row = row.RowNumber,
                            Code = row.NormalizedCode,
                            Message = $"Corequisite '{c}' is scheduled in Year {ys.Value.Year} Semester {ys.Value.Semester}, which differs from Year {row.Year} Semester {row.Semester}."
                        });
                    }
                }
            }
        }

        // ── 7. Counts Calculation & Idempotency ────────────────────────────────────
        int createCount = 0;
        int updateCount = 0;
        int unchangedCount = 0;

        foreach (var row in parsedRows)
        {
            if (!dbSubjectMap.TryGetValue(row.NormalizedCode, out var existing))
            {
                createCount++;
            }
            else
            {
                var diffFields = new List<string>();
                if (existing.SubjectTitle != row.Title) diffFields.Add(nameof(Subject.SubjectTitle));
                if (existing.LecUnits != row.LecUnits) diffFields.Add(nameof(Subject.LecUnits));
                if (existing.LabUnits != row.LabUnits) diffFields.Add(nameof(Subject.LabUnits));
                if (existing.LecHours != row.LecHours) diffFields.Add(nameof(Subject.LecHours));
                if (existing.LabHours != row.LabHours) diffFields.Add(nameof(Subject.LabHours));
                if (existing.YearLevel != row.Year) diffFields.Add(nameof(Subject.YearLevel));
                if (existing.DefaultSemester != row.Semester) diffFields.Add(nameof(Subject.DefaultSemester));
                if (existing.StandingYear != row.StandingYear) diffFields.Add(nameof(Subject.StandingYear));
                if (row.IsMinor.HasValue && existing.IsMinor != row.IsMinor.Value) diffFields.Add(nameof(Subject.IsMinor));

                if (diffFields.Count > 0)
                {
                    updateCount++;
                    warnings.Add(new CurriculumImportFindingDto
                    {
                        Row = row.RowNumber,
                        Code = row.NormalizedCode,
                        Message = $"Subject '{row.NormalizedCode}' exists with different values for: {string.Join(", ", diffFields)}. {(updateExisting ? "Will update." : "Pass updateExisting=true to update.")}"
                    });
                }
                else
                {
                    unchangedCount++;
                }
            }
        }

        // Requisite counts
        int prereqsToAdd = 0;
        int coreqsToAdd = 0;
        int alreadyExist = 0;
        int extrasInDb = 0;

        var allDbLinks = dbSubjectIds.Count > 0
            ? await _context.SubjectPrerequisites
                .Include(sp => sp.Subject)
                .Include(sp => sp.PrerequisiteSubject)
                .Where(sp => dbSubjectIds.Contains(sp.SubjectID))
                .ToListAsync()
            : new List<SubjectPrerequisite>();

        var dbLinksSet = new HashSet<(string S, string P, int Type)>(
            allDbLinks.Where(l => l.Subject != null && l.PrerequisiteSubject != null)
                      .Select(l => (SubjectService.NormalizeSubjectCode(l.Subject!.SubjectCode),
                                    SubjectService.NormalizeSubjectCode(l.PrerequisiteSubject!.SubjectCode),
                                    l.RequisiteType)));

        var csvLinks = new List<(string S, string P, int Type)>();
        foreach (var row in parsedRows)
        {
            var pSet = new HashSet<string>(row.Prerequisites, StringComparer.OrdinalIgnoreCase);
            foreach (var p in pSet)
            {
                csvLinks.Add((row.NormalizedCode, p, RequisiteTypeConstants.Prerequisite));
            }

            var cSet = new HashSet<string>(row.Corequisites, StringComparer.OrdinalIgnoreCase);
            foreach (var c in cSet)
            {
                csvLinks.Add((row.NormalizedCode, c, RequisiteTypeConstants.Corequisite));
            }
        }

        foreach (var link in csvLinks)
        {
            if (dbLinksSet.Contains(link))
            {
                alreadyExist++;
            }
            else
            {
                if (link.Type == RequisiteTypeConstants.Prerequisite)
                {
                    prereqsToAdd++;
                }
                else
                {
                    coreqsToAdd++;
                }
            }
        }

        var csvCodesSet = new HashSet<string>(parsedRows.Select(r => r.NormalizedCode), StringComparer.OrdinalIgnoreCase);
        var csvLinksSet = new HashSet<(string S, string P, int Type)>(csvLinks);
        foreach (var link in dbLinksSet)
        {
            if (csvCodesSet.Contains(link.S) && !csvLinksSet.Contains(link))
            {
                extrasInDb++;
            }
        }

        // ── 8. Apply (dryRun = false) ──────────────────────────────────────────────
        if (!dryRun && errors.Count == 0 && programEntity != null)
        {
            await using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var applyCurriculumId = targetCurriculumId
                    ?? await new CurriculumService(_context).NewestOrCreateAsync(programEntity.ProgramID);
                var entityMap = new Dictionary<string, Subject>(StringComparer.OrdinalIgnoreCase);
                foreach (var s in dbSubjects)
                {
                    entityMap[SubjectService.NormalizeSubjectCode(s.SubjectCode)] = s;
                }

                // 1. Insert or update subjects
                foreach (var row in parsedRows)
                {
                    if (entityMap.TryGetValue(row.NormalizedCode, out var existing))
                    {
                        if (updateExisting)
                        {
                            existing.SubjectTitle = row.Title;
                            existing.LecUnits = row.LecUnits;
                            existing.LabUnits = row.LabUnits;
                            existing.LecHours = row.LecHours;
                            existing.LabHours = row.LabHours;
                            existing.YearLevel = row.Year;
                            existing.DefaultSemester = row.Semester;
                            existing.StandingYear = row.StandingYear;
                            if (row.IsMinor.HasValue)
                            {
                                existing.IsMinor = row.IsMinor.Value;
                            }
                            _context.Subjects.Update(existing);
                        }
                    }
                    else
                    {
                        var newSubject = new Subject
                        {
                            SubjectID = Guid.NewGuid(),
                            SubjectCode = row.NormalizedCode,
                            SubjectTitle = row.Title,
                            LecUnits = row.LecUnits,
                            LabUnits = row.LabUnits,
                            LecHours = row.LecHours,
                            LabHours = row.LabHours,
                            ProgramID = programEntity.ProgramID,
                            CurriculumID = applyCurriculumId,
                            YearLevel = row.Year,
                            DefaultSemester = row.Semester,
                            StandingYear = row.StandingYear,
                            IsMinor = row.IsMinor ?? false
                        };
                        await _context.Subjects.AddAsync(newSubject);
                        entityMap[row.NormalizedCode] = newSubject;
                    }
                }

                await _context.SaveChangesAsync();

                // 2. Insert new requisite links
                foreach (var link in csvLinks)
                {
                    if (!dbLinksSet.Contains(link))
                    {
                        var subj = entityMap[link.S];
                        var prereqSubj = entityMap[link.P];

                        var newPrereq = new SubjectPrerequisite
                        {
                            PrerequisiteID = Guid.NewGuid(),
                            SubjectID = subj.SubjectID,
                            PrerequisiteSubjectID = prereqSubj.SubjectID,
                            RequisiteType = link.Type
                        };
                        await _context.SubjectPrerequisites.AddAsync(newPrereq);
                        dbLinksSet.Add(link);
                    }
                }

                await _context.SaveChangesAsync();
                await transaction.CommitAsync();
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        return BuildResponse(
            dryRun,
            targetProgramCode,
            createCount,
            updateCount,
            unchangedCount,
            prereqsToAdd,
            coreqsToAdd,
            alreadyExist,
            extrasInDb,
            warnings,
            errors);
    }

    private static bool CanReach(string start, string target, Dictionary<string, HashSet<string>> graph)
    {
        var visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var queue = new Queue<string>();
        queue.Enqueue(start);
        visited.Add(start);

        while (queue.Count > 0)
        {
            var curr = queue.Dequeue();
            if (curr.Equals(target, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (graph.TryGetValue(curr, out var neighbors))
            {
                foreach (var next in neighbors)
                {
                    if (visited.Add(next))
                    {
                        queue.Enqueue(next);
                    }
                }
            }
        }

        return false;
    }

    private static CurriculumImportResponseDto BuildResponse(
        bool dryRun,
        string program,
        int create,
        int update,
        int unchanged,
        int prereqsToAdd,
        int coreqsToAdd,
        int alreadyExist,
        int extrasInDb,
        List<CurriculumImportFindingDto> warnings,
        List<CurriculumImportFindingDto> errors)
    {
        return new CurriculumImportResponseDto
        {
            DryRun = dryRun,
            Program = program,
            Subjects = new SubjectCountsDto
            {
                Create = create,
                Update = update,
                Unchanged = unchanged
            },
            Requisites = new RequisiteCountsDto
            {
                PrerequisitesToAdd = prereqsToAdd,
                CorequisitesToAdd = coreqsToAdd,
                AlreadyExist = alreadyExist,
                ExtrasInDatabase = extrasInDb
            },
            Warnings = warnings.Take(200).ToList(),
            Errors = errors.Take(200).ToList(),
            TotalWarnings = warnings.Count,
            TotalErrors = errors.Count
        };
    }

    private class CsvRowData
    {
        public int RowNumber { get; set; }
        public string Program { get; set; } = string.Empty;
        public string RawCode { get; set; } = string.Empty;
        public string NormalizedCode { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public decimal Units { get; set; }
        public decimal LecUnits { get; set; }
        public decimal LabUnits { get; set; }
        public decimal LecHours { get; set; }
        public decimal LabHours { get; set; }
        public int Year { get; set; }
        public int Semester { get; set; }
        public int? StandingYear { get; set; }
        public bool? IsMinor { get; set; }
        public List<string> Prerequisites { get; set; } = new();
        public List<string> Corequisites { get; set; } = new();
    }
}
