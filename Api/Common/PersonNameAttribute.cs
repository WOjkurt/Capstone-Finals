using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace Api.Common;

/// <summary>
/// English letters plus the Filipino Ñ, spaces, hyphens, apostrophes and periods, or "N/A" for a field
/// that does not apply. Empty is left to [Required].
/// </summary>
[AttributeUsage(AttributeTargets.Property)]
public sealed partial class PersonNameAttribute : ValidationAttribute
{
    [GeneratedRegex(@"^[A-Za-zÑñ '’.\-]+\z")]
    private static partial Regex Allowed();

    public override bool IsValid(object? value) =>
        value is not string text || text.Length == 0 ||
        text.Trim().Equals("N/A", StringComparison.OrdinalIgnoreCase) || Allowed().IsMatch(text);

    public override string FormatErrorMessage(string name)
    {
        var label = Regex.Replace(name, "(?<=[a-z])(?=[A-Z])", " ");
        return $"{label} can only use English letters, Ñ, spaces, hyphens, apostrophes and periods.";
    }
}
