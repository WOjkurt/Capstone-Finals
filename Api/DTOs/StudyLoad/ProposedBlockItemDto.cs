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

    public string Category { get; set; } = "regular"; // "regular" | "retake" | "back_subject"
    public int SubjectYearLevel { get; set; }
    public decimal Units { get; set; }
    public decimal? LastGrade { get; set; }
    public string? LastGradeTerm { get; set; }
    public string StandingStatus { get; set; } = "not_required"; // "not_required" | "met" | "unmet"
    public List<ProposedBlockCorequisiteDto> Corequisites { get; set; } = new();
}

public class ProposedBlockCorequisiteDto
{
    public Guid SubjectId { get; set; }
    public required string SubjectCode { get; set; }
    public bool IncludedInProposal { get; set; }
}
