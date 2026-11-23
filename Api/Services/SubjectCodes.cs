namespace Api.Services;

/// <summary>
/// Turning the many ways a subject code gets written into one comparable key.
///
/// "GEC 112B ELEC3", "GEC 112B-Elec 3" and "gec112belec3" are the same subject; only letters
/// and digits survive, upper-cased. This is the definition the Excel import has always used to
/// match a code in a spreadsheet to a subject in the system, and it is now also how the study
/// load builder decides whether two Subject rows mean the same subject.
/// </summary>
public static class SubjectCodes
{
    public static string Key(string code) =>
        new string(code.ToUpperInvariant().Where(char.IsAsciiLetterOrDigit).ToArray());
}
