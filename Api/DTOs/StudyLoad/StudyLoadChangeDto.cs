namespace Api.DTOs.StudyLoad;

/// <summary>One line of the Adding/Dropping form.</summary>
public class StudyLoadChangeDto
{
    public Guid ChangeId { get; set; }
    public Guid StudyLoadId { get; set; }
    /// <summary>Added, Dropped, Withdrawn or Re-enrolled.</summary>
    public string Kind { get; set; } = string.Empty;
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public string ClassName { get; set; } = string.Empty;
    public decimal Units { get; set; }
    public string? Reason { get; set; }
    public string? ChangedBy { get; set; }
    public DateTime ChangedAt { get; set; }
}
