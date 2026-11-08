using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Api.Common;

/// <summary>Removes accent marks from a name (José becomes Jose). Ñ stays, as it is a letter of Filipino names.</summary>
public static class PersonNameText
{
    public static string Plain(string text)
    {
        var plain = new StringBuilder(text.Length);
        foreach (char letter in text.Normalize(NormalizationForm.FormC))
        {
            if (letter is 'Ñ' or 'ñ')
            {
                plain.Append(letter);
                continue;
            }
            foreach (char part in letter.ToString().Normalize(NormalizationForm.FormD))
            {
                if (CharUnicodeInfo.GetUnicodeCategory(part) != UnicodeCategory.NonSpacingMark) plain.Append(part);
            }
        }
        return plain.ToString();
    }
}

/// <summary>Reads a name with its accent marks removed, so [PersonName] sees the plain spelling.</summary>
public sealed class PlainNameConverter : JsonConverter<string>
{
    public override string? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        reader.GetString() is { } text ? PersonNameText.Plain(text) : null;

    public override void Write(Utf8JsonWriter writer, string value, JsonSerializerOptions options) =>
        writer.WriteStringValue(value);
}
