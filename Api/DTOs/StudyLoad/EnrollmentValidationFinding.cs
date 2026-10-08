namespace Api.DTOs.StudyLoad;

public class EnrollmentValidationFinding
{
    public required string Code { get; set; }
    public required string Message { get; set; }
    public Guid? SubjectId { get; set; }
    public string? SubjectCode { get; set; }
}

public static class EnrollmentRuleCodes
{
    public const string PrerequisiteNotTaken = "PREREQUISITE_NOT_TAKEN";
    public const string PrerequisiteFailed = "PREREQUISITE_FAILED";
    public const string PrerequisiteInProgress = "PREREQUISITE_IN_PROGRESS";
    public const string PrerequisiteDropped = "PREREQUISITE_DROPPED";
    public const string AlreadyPassed = "ALREADY_PASSED";
    public const string SameSubjectThisTerm = "SAME_SUBJECT_THIS_TERM";
}
