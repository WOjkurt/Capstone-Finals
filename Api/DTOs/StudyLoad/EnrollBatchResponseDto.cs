namespace Api.DTOs.StudyLoad;

public class EnrollBatchResponseDto
{
    public Guid ClassId { get; set; }
    public bool Enrolled { get; set; }
    public Guid? StudyLoadId { get; set; }
    public List<string> Reasons { get; set; } = new();
}
