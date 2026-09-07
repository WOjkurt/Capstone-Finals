using System.Text.Json;
using System.Text.Json.Serialization;

namespace Api.DTOs.Enrollment;

/// <summary>
/// Container for the raw applicant-submitted data stored as jsonb in EnrollmentResponse.Data.
/// Structure mirrors the real EnrollmentForm and Contact schemas precisely for direct,
/// lossless pre-filling on the Registrar side.
/// </summary>
public class ResponseDataDto
{
    public ResponseFormDataDto? Form { get; set; }
    public List<ResponseContactDto> Contacts { get; set; } = [];
}

/// <summary>
/// Nested form object matching the real EnrollmentForm schema precisely:
/// firstName, middleName, lastName, suffix, dateOfBirth, placeOfBirth,
/// sex, civilStatus, nationality, mobileNumber, barangay, cityOfMunicipality,
/// province, zipCode, lastSchoolAttended, schoolAddress, shsStrand (int),
/// yearGraduated, previousCollege, previousCourse.
/// </summary>
public class ResponseFormDataDto
{
    // ── Personal Information ─────────────────────────────────────────────────
    public string FirstName { get; set; } = string.Empty;
    public string? MiddleName { get; set; }
    public string LastName { get; set; } = string.Empty;
    public string? Suffix { get; set; }

    /// <summary>Date of birth (e.g. "2005-08-12").</summary>
    public string? DateOfBirth { get; set; }
    public string? PlaceOfBirth { get; set; }
    public string? Sex { get; set; }
    public string? CivilStatus { get; set; }
    public string? Nationality { get; set; }

    // ── Contact & Address ────────────────────────────────────────────────────
    public string? MobileNumber { get; set; }
    public string? Barangay { get; set; }

    /// <summary>Matches schema's "CityOfMunicipality" (not "cityMunicipality").</summary>
    [JsonPropertyName("cityOfMunicipality")]
    public string? CityOfMunicipality { get; set; }

    /// <summary>Alias for backwards-compatibility when deserializing cityMunicipality.</summary>
    [JsonPropertyName("cityMunicipality")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? CityMunicipality
    {
        get => null; // only serialize cityOfMunicipality to jsonb
        set { if (string.IsNullOrEmpty(CityOfMunicipality)) CityOfMunicipality = value; }
    }

    public string? Province { get; set; }
    public string? ZipCode { get; set; }

    // ── Educational Background ───────────────────────────────────────────────
    public string? LastSchoolAttended { get; set; }
    public string? SchoolAddress { get; set; }

    /// <summary>SHS Strand lookup ID (int, e.g. 1 = STEM, 2 = HUMSS, 3 = ABM, 4 = GAS, 5 = TVL).</summary>
    [JsonConverter(typeof(ShsStrandJsonConverter))]
    public int SHSStrand { get; set; }

    /// <summary>Year graduated (e.g. "2024" or "2024-03-31").</summary>
    public string? YearGraduated { get; set; }

    public string? PreviousCollege { get; set; }
    public string? PreviousCourse { get; set; }

    // ── Optional Additional Fields ───────────────────────────────────────────
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? YearLevel { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? PreviousStudentID { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? IntendedProgramCode { get; set; }

    /// <summary>Supports payloads where contacts array was nested inside the form object.</summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<ResponseContactDto>? Contacts { get; set; }
}

/// <summary>
/// Contact item matching the Contact table schema precisely:
/// firstName, lastName, relationType (int), occupation, contactNo.
/// </summary>
public class ResponseContactDto
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;

    /// <summary>Lookup ID matching Contact.RelationType (int, e.g. 1 = Father, 2 = Mother, 3 = Guardian).</summary>
    [JsonConverter(typeof(RelationTypeJsonConverter))]
    public int RelationType { get; set; }

    public string Occupation { get; set; } = string.Empty;
    public string ContactNo { get; set; } = string.Empty;

    // ── Graceful Fallback Deserializers for Google Forms Webhooks ─────────────
    [JsonPropertyName("contactName")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ContactName
    {
        get => null;
        set
        {
            if (!string.IsNullOrWhiteSpace(value) && string.IsNullOrEmpty(FirstName) && string.IsNullOrEmpty(LastName))
            {
                var parts = value.Trim().Split(' ', 2);
                FirstName = parts[0];
                LastName = parts.Length > 1 ? parts[1] : string.Empty;
            }
        }
    }

    [JsonPropertyName("relationship")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Relationship
    {
        get => null;
        set
        {
            if (!string.IsNullOrWhiteSpace(value) && RelationType == 0)
            {
                if (int.TryParse(value, out var parsed)) RelationType = parsed;
                else if (value.Contains("Father", StringComparison.OrdinalIgnoreCase)) RelationType = 1;
                else if (value.Contains("Mother", StringComparison.OrdinalIgnoreCase)) RelationType = 2;
                else RelationType = 3;
            }
        }
    }

    [JsonPropertyName("contactNumber")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ContactNumber
    {
        get => null;
        set { if (!string.IsNullOrEmpty(value) && string.IsNullOrEmpty(ContactNo)) ContactNo = value; }
    }
}

public class ShsStrandJsonConverter : JsonConverter<int>
{
    public override int Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.Number)
        {
            return reader.GetInt32();
        }

        if (reader.TokenType == JsonTokenType.String)
        {
            var str = reader.GetString();
            if (int.TryParse(str, out var val)) return val;
            if (string.IsNullOrWhiteSpace(str)) return 0;

            if (str.Contains("STEM", StringComparison.OrdinalIgnoreCase)) return 1;
            if (str.Contains("HUMSS", StringComparison.OrdinalIgnoreCase)) return 2;
            if (str.Contains("ABM", StringComparison.OrdinalIgnoreCase)) return 3;
            if (str.Contains("GAS", StringComparison.OrdinalIgnoreCase)) return 4;
            if (str.Contains("TVL", StringComparison.OrdinalIgnoreCase)) return 5;
        }

        return 0;
    }

    public override void Write(Utf8JsonWriter writer, int value, JsonSerializerOptions options)
    {
        writer.WriteNumberValue(value);
    }
}

public class RelationTypeJsonConverter : JsonConverter<int>
{
    public override int Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.Number)
        {
            return reader.GetInt32();
        }

        if (reader.TokenType == JsonTokenType.String)
        {
            var str = reader.GetString();
            if (int.TryParse(str, out var val)) return val;
            if (string.IsNullOrWhiteSpace(str)) return 0;

            if (str.Contains("Father", StringComparison.OrdinalIgnoreCase)) return 1;
            if (str.Contains("Mother", StringComparison.OrdinalIgnoreCase)) return 2;
            if (str.Contains("Guardian", StringComparison.OrdinalIgnoreCase)) return 3;
        }

        return 0;
    }

    public override void Write(Utf8JsonWriter writer, int value, JsonSerializerOptions options)
    {
        writer.WriteNumberValue(value);
    }
}
