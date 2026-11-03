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

    // Unit limit for the term (Enrolled + Pending units vs the CHED limit) and any recorded overload approval.
    public decimal TermUnits { get; set; }
    public decimal MaxUnits { get; set; }
    public bool IsOverloaded { get; set; }
    public string? OverloadReason { get; set; }
    public string? OverloadApprovedBy { get; set; }
}
