namespace Api.Common;

public readonly record struct StudentIdResult(bool IsValid, string? Number, string? ErrorMessage);

/// <summary>
/// DBTC student IDs are digits, for example 25060208 (8 digits) or 8090037 (older 7-digit numbers).
/// Leading zeros are kept, so the number is stored as text.
/// </summary>
public static class StudentIdHelper
{
    public const int MinDigits = 4;
    public const int MaxDigits = 15;

    /// <summary>Removes spaces and dashes. Empty means "no student ID yet" (first years may not have one).</summary>
    public static StudentIdResult Normalize(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return new(true, null, null);
        var stripped = raw.Trim().Replace(" ", "").Replace("-", "");
        if (stripped.Length == 0) return new(true, null, null);
        if (stripped.Any(c => !char.IsAsciiDigit(c)))
        {
            return new(false, null, "The student ID must contain digits only.");
        }
        if (stripped.Length is < MinDigits or > MaxDigits)
        {
            return new(false, null, $"The student ID must be {MinDigits} to {MaxDigits} digits.");
        }
        return new(true, stripped, null);
    }
}
