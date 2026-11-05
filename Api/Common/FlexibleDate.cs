using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Api.Common;

/// <summary>
/// Reads dates as people and the Google Form write them: "2007-05-01", "5/1/2007", "May 1, 2007",
/// or just a year ("2024") or year and month ("2024-05"). Month comes before day, as in the Philippines.
/// </summary>
public static class FlexibleDate
{
    private static readonly string[] Formats =
    {
        "yyyy-M-d", "M/d/yyyy", "M-d-yyyy", "MMMM d, yyyy", "MMM d, yyyy", "MMMM d yyyy", "MMM d yyyy", "yyyy-MM-ddTHH:mm:ss", "yyyy-MM-ddTHH:mm:ssZ"
    };

    public static bool TryParse(string? text, out DateOnly? date)
    {
        date = null;
        var value = text?.Trim();
        if (string.IsNullOrEmpty(value)) return true;

        if (Regex.IsMatch(value, @"^\d{4}$")) value += "-1-1";
        else if (Regex.IsMatch(value, @"^\d{4}-\d{1,2}$")) value += "-1";

        if (!DateTime.TryParseExact(value, Formats, CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed)) return false;
        if (parsed.Year is < 1900 or > 2100) return false;
        date = DateOnly.FromDateTime(parsed);
        return true;
    }

    public static string Message(string? text) =>
        $"\"{text}\" is not a date we can read. Type it like 2007-05-01, 5/1/2007, or just the year for Year Graduated.";
}

/// <summary>For a date that must have a value in code; empty text becomes the default date, meaning "not given".</summary>
public class FlexibleDateConverter : JsonConverter<DateOnly>
{
    public override DateOnly Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var text = reader.GetString();
        return FlexibleDate.TryParse(text, out var date) ? date ?? default : throw new JsonException(FlexibleDate.Message(text));
    }

    public override void Write(Utf8JsonWriter writer, DateOnly value, JsonSerializerOptions options) =>
        writer.WriteStringValue(value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
}

public class FlexibleNullableDateConverter : JsonConverter<DateOnly?>
{
    public override DateOnly? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var text = reader.GetString();
        return FlexibleDate.TryParse(text, out var date) ? date : throw new JsonException(FlexibleDate.Message(text));
    }

    public override void Write(Utf8JsonWriter writer, DateOnly? value, JsonSerializerOptions options)
    {
        if (value is { } d) writer.WriteStringValue(d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
        else writer.WriteNullValue();
    }
}
