namespace Api.DTOs.StudyLoad;

public class EnrollBatchRequestDto
{
    public Guid UserId { get; set; }
    public Guid TermId { get; set; }
    public List<Guid> ClassIds { get; set; } = new();
}
