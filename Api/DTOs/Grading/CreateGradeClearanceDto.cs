namespace Api.DTOs.Grading;

public class CreateGradeClearanceDto
{
    public Guid UserId { get; set; }
    public Guid TermId { get; set; }
    public bool? IsCleared { get; set; }
}
