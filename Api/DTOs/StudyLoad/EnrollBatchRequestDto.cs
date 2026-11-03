namespace Api.DTOs.StudyLoad;

public class EnrollBatchRequestDto
{
    public Guid UserId { get; set; }
    public Guid TermId { get; set; }
    public List<Guid> ClassIds { get; set; } = new();
    public bool AsPending { get; set; } = false;

    /// <summary>Required when the save takes the student over the term's unit limit; recorded as the overload approval.</summary>
    [System.ComponentModel.DataAnnotations.MaxLength(Api.Constants.ValidationConstants.NotesMax)]
    public string? OverloadReason { get; set; }
}
