namespace Api.DTOs.StudyLoad;

public class FinalizeStudyLoadsRequestDto
{
    public Guid UserId { get; set; }
    public Guid TermId { get; set; }
    public List<Guid>? StudyLoadIds { get; set; }
}
