namespace Api.DTOs.StudyLoad;

/// <summary>
/// Suggested next year level for a student. The Registrar always makes the final decision.
/// Rule: a student moves up after passing at least 75% of the units of their current year level's subjects
/// and at least 75% of that year's major units (when the year has majors).
/// </summary>
public class YearLevelSuggestionDto
{
    public int CurrentYearLevel { get; set; }
    public int SuggestedYearLevel { get; set; }
    public decimal PassedUnits { get; set; }
    public decimal TotalUnits { get; set; }
    public decimal PassedMajorUnits { get; set; }
    public decimal TotalMajorUnits { get; set; }
    public int PassedSubjects { get; set; }
    public int TotalSubjects { get; set; }
    /// <summary>Enrolled subjects of this year level that have no final grade yet.</summary>
    public int UngradedSubjects { get; set; }
    public List<string> FailedSubjectCodes { get; set; } = new();
    public List<string> NotTakenSubjectCodes { get; set; } = new();
    public bool IsFinalYear { get; set; }
    public string Reason { get; set; } = string.Empty;
}
