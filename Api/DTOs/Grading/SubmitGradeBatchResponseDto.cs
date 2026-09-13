namespace Api.DTOs.Grading;

public class SubmitGradeBatchResponseDto
{
    public List<GradeResponseDto> Succeeded { get; set; } = new();
    public List<GradeBatchFailedItemDto> Failed { get; set; } = new();
}

public class GradeBatchFailedItemDto
{
    public Guid StudyLoadId { get; set; }
    public string Reason { get; set; } = string.Empty;
}
