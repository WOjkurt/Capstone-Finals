namespace Api.DTOs.StudyLoad;

public class EnrollSingleResponseDto
{
    public bool Success { get; set; }
    public Guid? StudyLoadId { get; set; }
    public List<string> Warnings { get; set; } = new();
}
