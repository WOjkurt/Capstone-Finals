namespace Api.Common;

/// <summary>
/// Formats a human-readable term label from a school year and semester number.
/// Semester 1 → "1st Sem", 2 → "2nd Sem", 3 → "Summer".
/// </summary>
public static class TermLabel
{
    /// <summary>
    /// Returns a label such as "2026-2027 (1st Sem)", "2026-2027 (2nd Sem)", or "2026-2027 (Summer)".
    /// </summary>
    public static string Format(string schoolYear, int semester)
    {
        var semPart = semester switch
        {
            1 => "1st Sem",
            2 => "2nd Sem",
            3 => "Summer",
            _ => $"Sem {semester}"
        };
        return $"{schoolYear} ({semPart})";
    }
}
