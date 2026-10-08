namespace Api.DTOs.StudyLoad;

public class ProposedBlockItemDto
{
    public Guid SubjectId { get; set; }
    public required string SubjectCode { get; set; }
    public required string SubjectTitle { get; set; }
    public Guid? ClassId { get; set; }
    public string? ClassName { get; set; }
    public required string MatchType { get; set; } // "auto" | "multiple_found" | "no_class_offered"
    public List<ClassOptionDto>? Options { get; set; }
    public string PrerequisiteStatus { get; set; } = "met"; // "met" | "unmet"
    public List<string> PrerequisiteMessages { get; set; } = new();
    public bool AlreadyPassed { get; set; }
    public bool AlreadyEnrolledThisTerm { get; set; }
}
