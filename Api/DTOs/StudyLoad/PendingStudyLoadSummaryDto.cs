namespace Api.DTOs.StudyLoad;

public class PendingStudyLoadSummaryDto
{
    public Guid UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? Lrn { get; set; }
    public string? ProgramCode { get; set; }
    public string? ProgramName { get; set; }
    public int? YearLevel { get; set; }
    public int PendingCount { get; set; }
    public decimal PendingUnits { get; set; }
}
