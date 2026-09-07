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
}
