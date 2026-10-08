namespace Api.Constants;

/// <summary>
/// Integer values for SubjectPrerequisite.RequisiteType.
/// 0 = Prerequisite (must be passed before enrolling in the subject).
/// 1 = Corequisite (must be taken in the same term).
/// </summary>
public static class RequisiteTypeConstants
{
    /// <summary>The subject must be passed before the student may enroll.</summary>
    public const int Prerequisite = 0;

    /// <summary>The subject must be taken concurrently in the same term.</summary>
    public const int Corequisite = 1;
}
