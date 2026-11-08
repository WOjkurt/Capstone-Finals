using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Api.Common;

/// <summary>Cleans and checks Philippine phone numbers and ZIP codes.</summary>
public static partial class PhoneAndZip
{
    [GeneratedRegex(@"^09\d{9}\z")]
    private static partial Regex Mobile();

    // An area code (02 to 08) and the local number, for example 0322531234 or 0281234567.
    [GeneratedRegex(@"^0[2-8]\d{7,9}\z")]
    private static partial Regex Landline();

    [GeneratedRegex(@"^\d{4}\z")]
    private static partial Regex Zip();

    [GeneratedRegex(@"[\s\-().]")]
    private static partial Regex Separators();

    /// <summary>
    /// Removes spaces, dashes, brackets and dots, and writes +63 / 63 numbers as 0 numbers:
    /// "+63 917 123 4567" becomes "09171234567". Anything that is not a phone number comes back trimmed and unchanged.
    /// </summary>
    public static string? CleanPhone(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return value;
        var digits = Separators().Replace(value, "");
        if (digits.StartsWith("+63")) digits = "0" + digits[3..];
        else if (digits.StartsWith("63") && digits.Length == 12) digits = "0" + digits[2..];
        else if (digits.StartsWith('9') && digits.Length == 10) digits = "0" + digits;
        return IsMobile(digits) || IsLandline(digits) ? digits : value.Trim();
    }

    public static bool IsMobile(string value) => Mobile().IsMatch(value);

    public static bool IsLandline(string value) => Landline().IsMatch(value);

    public static string? CleanZip(string? value) =>
        string.IsNullOrWhiteSpace(value) ? value : value.Replace(" ", "").Trim();

    public static bool IsZip(string value) => Zip().IsMatch(value);
}

/// <summary>A mobile number: 11 digits starting with 09. Empty is left to [Required].</summary>
[AttributeUsage(AttributeTargets.Property)]
public sealed class MobileNumberAttribute : ValidationAttribute
{
    public MobileNumberAttribute() : base("{0} must be 11 digits starting with 09, for example 09171234567.") { }

    public override bool IsValid(object? value) =>
        value is not string text || text.Length == 0 || PhoneAndZip.IsMobile(text);

    public override string FormatErrorMessage(string name) => string.Format(ErrorMessageString, Label(name));

    internal static string Label(string name) => Regex.Replace(name, "(?<=[a-z])(?=[A-Z])", " ");
}

/// <summary>
/// A mobile number or a landline with its area code, or "N/A" for a parent with no number.
/// Empty is left to [Required].
/// </summary>
[AttributeUsage(AttributeTargets.Property)]
public sealed class PhoneNumberAttribute : ValidationAttribute
{
    public PhoneNumberAttribute()
        : base("{0} must be a mobile number like 09171234567 or a landline with its area code like 0322531234.") { }

    public override bool IsValid(object? value) =>
        value is not string text || text.Length == 0 || PhoneAndZip.IsMobile(text) || PhoneAndZip.IsLandline(text) ||
        text.Trim().Equals("N/A", StringComparison.OrdinalIgnoreCase);

    public override string FormatErrorMessage(string name) =>
        string.Format(ErrorMessageString, MobileNumberAttribute.Label(name));
}

/// <summary>A 4-digit ZIP code. Empty is left to [Required].</summary>
[AttributeUsage(AttributeTargets.Property)]
public sealed class ZipCodeAttribute : ValidationAttribute
{
    public ZipCodeAttribute() : base("{0} must be 4 digits, for example 6000.") { }

    public override bool IsValid(object? value) =>
        value is not string text || text.Length == 0 || PhoneAndZip.IsZip(text);

    public override string FormatErrorMessage(string name) =>
        string.Format(ErrorMessageString, MobileNumberAttribute.Label(name));
}

/// <summary>Reads a phone number already cleaned, so the check sees "09171234567" and not "+63 917-123-4567".</summary>
public sealed class CleanPhoneConverter : JsonConverter<string>
{
    public override string? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        PhoneAndZip.CleanPhone(reader.GetString());

    public override void Write(Utf8JsonWriter writer, string value, JsonSerializerOptions options) =>
        writer.WriteStringValue(value);
}

/// <summary>Reads a ZIP code with spaces removed.</summary>
public sealed class CleanZipConverter : JsonConverter<string>
{
    public override string? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        PhoneAndZip.CleanZip(reader.GetString());

    public override void Write(Utf8JsonWriter writer, string value, JsonSerializerOptions options) =>
        writer.WriteStringValue(value);
}
