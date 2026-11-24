namespace Api.Common;

/// <summary>
/// Age from a birthday, in one place. The applicant is never asked for it and never trusted with
/// it: the enrollment form carries an Age because the Registrar's printouts want one, and it is
/// worked out from the date of birth wherever a form is recorded.
/// </summary>
public static class Ages
{
    /// <summary>Null when the birthday is missing or in the future, rather than a negative age.</summary>
    public static int? On(DateOnly birth, DateOnly today)
    {
        if (birth == default || birth > today) return null;
        int age = today.Year - birth.Year;
        if (birth > today.AddYears(-age)) age--;
        return age;
    }

    /// <summary>The same, for a date that arrived as text (the webhook and the public form both send text).</summary>
    public static int? On(string? birth, DateOnly today) =>
        DateOnly.TryParse(birth, out var parsed) ? On(parsed, today) : null;
}
