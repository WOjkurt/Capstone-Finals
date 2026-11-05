namespace Api.DTOs.StudyLoad;

public class EnrollSingleRequestDto
{
    public Guid UserId { get; set; }
    public Guid ClassId { get; set; }
    public bool Force { get; set; } = false;
    public string? ForceReason { get; set; }
    public bool AsPending { get; set; } = false;

    /// <summary>Why a subject is added after the student is already enrolled for the term. Required in that case.</summary>
    [System.ComponentModel.DataAnnotations.MaxLength(500)]
    public string? ChangeReason { get; set; }
}
