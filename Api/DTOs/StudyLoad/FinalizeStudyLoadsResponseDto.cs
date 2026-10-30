namespace Api.DTOs.StudyLoad;

public class FinalizeStudyLoadsResponseDto
{
    public bool Success { get; set; }
    public List<StudyLoadResponseDto> FinalizedLoads { get; set; } = new();
    public List<EnrollmentValidationFinding> Findings { get; set; } = new();
    public string? Message { get; set; }
}
