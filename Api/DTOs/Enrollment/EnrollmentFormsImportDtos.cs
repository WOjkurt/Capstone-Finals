namespace Api.DTOs.Enrollment;

/// <summary>What importing the Google Form's responses spreadsheet would do (dry run) or did.</summary>
public class EnrollmentFormsImportResultDto
{
    public bool DryRun { get; set; }
    /// <summary>Students who get the form saved.</summary>
    public int Forms { get; set; }
    /// <summary>Answers already imported earlier; skipped.</summary>
    public int AlreadyImported { get; set; }
    /// <summary>A student answered more than once; only the newest answer is kept.</summary>
    public int OlderAnswersSkipped { get; set; }
    /// <summary>Answers of people who are not students in the system (left out).</summary>
    public int NotInSystem { get; set; }
    public List<EnrollmentFormsImportRowDto> Rows { get; set; } = new();
    public List<Api.DTOs.Records.RecordsImportProblemDto> Problems { get; set; } = new();
    public int TotalProblems { get; set; }
}

public class EnrollmentFormsImportRowDto
{
    public int Row { get; set; }
    public string StudentId { get; set; } = string.Empty;
    public string StudentName { get; set; } = string.Empty;
    /// <summary>"school email" or "name".</summary>
    public string MatchedBy { get; set; } = string.Empty;
    /// <summary>Parents/guardian found in the answer.</summary>
    public int Contacts { get; set; }
}
