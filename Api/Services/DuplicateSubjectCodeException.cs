namespace Api.Services;

/// <summary>
/// Thrown when a subject code already exists in the same program.
/// Maps to HTTP 409 Conflict.
/// </summary>
public class DuplicateSubjectCodeException : Exception
{
    public string SubjectCode { get; }
    public string ProgramCode { get; }

    public DuplicateSubjectCodeException(string subjectCode, string programCode)
        : base($"A subject with code '{subjectCode}' already exists in program '{programCode}'.")
    {
        SubjectCode = subjectCode;
        ProgramCode = programCode;
    }
}
