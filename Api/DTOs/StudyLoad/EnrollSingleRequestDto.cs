namespace Api.DTOs.StudyLoad;

public class EnrollSingleRequestDto
{
    public Guid UserId { get; set; }
    public Guid ClassId { get; set; }
    public bool Force { get; set; } = false;
}
