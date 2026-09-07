namespace Api.DTOs.Grading;

public class GradeClearanceResponseDto
{
    public Guid ClearanceID { get; set; }
    public Guid UserID { get; set; }
    public Guid TermID { get; set; }
    public string? TermLabel { get; set; }
    public bool IsCleared { get; set; }
    public Guid? ClearedByUserID { get; set; }
    public string? ClearedByUserName { get; set; }
    public DateTime? ClearedAt { get; set; }
}
