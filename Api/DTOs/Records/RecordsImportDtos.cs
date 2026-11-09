namespace Api.DTOs.Records;

/// <summary>What an Excel import of old students and grades would do (dry run) or did.</summary>
public class RecordsImportResultDto
{
    public bool DryRun { get; set; }

    /// <summary>School years found in the grades file, newest first, e.g. "2025-2026".</summary>
    public List<string> SchoolYearsFound { get; set; } = new();
    public List<string> SchoolYearsImported { get; set; } = new();

    public int NewStudents { get; set; }
    public int ExistingStudents { get; set; }
    /// <summary>New students per program code.</summary>
    public Dictionary<string, int> StudentsPerProgram { get; set; } = new();
    /// <summary>New students per curriculum ("BTVTED-MT 2021 curriculum": 40).</summary>
    public Dictionary<string, int> StudentsPerCurriculum { get; set; } = new();

    public int GradesPassed { get; set; }
    public int GradesFailed { get; set; }
    public int Dropped { get; set; }
    /// <summary>Subjects with no final grade yet (NA or blank): saved as enrolled, without a grade.</summary>
    public int NoGradeYet { get; set; }
    /// <summary>Rows already in the system from an earlier import; skipped.</summary>
    public int AlreadyImported { get; set; }

    public List<string> TermsCreated { get; set; } = new();
    /// <summary>Terms whose grades are released to the students (they count as "cleared" for online enrollment).</summary>
    public bool GradesReleased { get; set; }

    /// <summary>Rows that were skipped, with the reason. At most 200 are listed; see <see cref="TotalProblems"/>.</summary>
    public List<RecordsImportProblemDto> Problems { get; set; } = new();
    public int TotalProblems { get; set; }

    /// <summary>Things to look at that did not stop the import, e.g. names without a middle name.</summary>
    public List<string> Notes { get; set; } = new();
}

public class RecordsImportProblemDto
{
    public string File { get; set; } = string.Empty;
    public string Sheet { get; set; } = string.Empty;
    public int Row { get; set; }
    public string Message { get; set; } = string.Empty;
}
