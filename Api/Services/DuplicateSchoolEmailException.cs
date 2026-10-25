namespace Api.Services;

/// <summary>
/// Thrown when a school email is already assigned to another enrollment application.
/// Maps to HTTP 409 Conflict.
/// </summary>
public class DuplicateSchoolEmailException : Exception
{
    public string SchoolEmail { get; }

    public DuplicateSchoolEmailException(string schoolEmail)
        : base($"The school email '{schoolEmail}' is already assigned to another enrollment application.")
    {
        SchoolEmail = schoolEmail;
    }
}
