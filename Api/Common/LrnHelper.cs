namespace Api.Common;

public readonly record struct LrnResult(bool IsValid, string? Lrn, string? ErrorMessage);

public static class LrnHelper
{
    public const int RequiredDigits = 12;

    /// <summary>
    /// Normalizes and validates an LRN:
    /// - Strips spaces and dashes.
    /// - Null, whitespace, or empty string is valid and returns null (empty means "no LRN").
    /// - If non-empty, must contain exactly 12 ASCII digits.
    /// - Returns a validation error message if invalid.
    /// </summary>
    public static LrnResult Normalize(string? rawLrn)
    {
        if (string.IsNullOrWhiteSpace(rawLrn))
        {
            return new LrnResult(true, null, null);
        }

        var stripped = rawLrn.Replace(" ", "").Replace("-", "");

        if (string.IsNullOrEmpty(stripped))
        {
            return new LrnResult(true, null, null);
        }

        if (stripped.Any(c => !char.IsAsciiDigit(c)))
        {
            return new LrnResult(false, null, "LRN must contain digits only.");
        }

        if (stripped.Length != RequiredDigits)
        {
            return new LrnResult(false, null, $"LRN must be exactly {RequiredDigits} digits.");
        }

        return new LrnResult(true, stripped, null);
    }
}
