namespace Api.DTOs.Audit;

public class ActivityLogEntryDto
{
    public Guid Id { get; set; }
    public DateTime OccurredAt { get; set; }
    public Guid? ActorUserId { get; set; }
    public string ActorName { get; set; } = string.Empty;
    public int? ActorRole { get; set; }
    public string Action { get; set; } = string.Empty;
    public Guid? StudentUserId { get; set; }
    public string? StudentName { get; set; }
    public string? TermLabel { get; set; }
    public string Summary { get; set; } = string.Empty;
}

public class ActivityLogPageDto
{
    public List<ActivityLogEntryDto> Items { get; set; } = new();
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalCount { get; set; }
}
