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
/// Nested form object matching the expanded EnrollmentForm schema.
/// All fields are optional (nullable) because this is an untrusted webhook payload
/// and field presence varies by Google Form version.
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

    // New personal fields
    public string? Gender { get; set; }

    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? Age { get; set; }

    public string? BloodType { get; set; }
    public string? Religion { get; set; }
    public string? FacebookName { get; set; }

    // ── Primary Address ──────────────────────────────────────────────────────
    public string? MobileNumber { get; set; }
    public string? HouseStreet { get; set; }
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

    // ── Secondary / Provincial Address (optional) ────────────────────────────
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ProvHouseStreet { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ProvBarangay { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ProvCityMunicipality { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ProvProvince { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ProvZipCode { get; set; }

    // ── Educational Background ───────────────────────────────────────────────
    public string? LastSchoolAttended { get; set; }
    public string? SchoolAddress { get; set; }

    /// <summary>
    /// Free-text program/track/strand/specialization (replaces the old SHSStrand int lookup).
    /// The Google Form now collects this as an open-ended text answer, so no converter needed.
    /// </summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ProgramTrackStrand { get; set; }

    /// <summary>Year graduated (e.g. "2024" or "2024-03-31").</summary>
    public string? YearGraduated { get; set; }

    public string? PreviousCollege { get; set; }
    public string? PreviousCourse { get; set; }

    // ── Enrollment Metadata ──────────────────────────────────────────────────
    /// <summary>1 = New, 2 = Old, 3 = Transferee.</summary>
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? StudentType { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? LRN { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? AcademicYear { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? IncomingCourse { get; set; }

    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? YearLevel { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? PreviousStudentID { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? IntendedProgramCode { get; set; }

    // ── Family Information ───────────────────────────────────────────────────
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? BirthOrder { get; set; }

    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? NumberOfSiblings { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? FamilyStatus { get; set; }

    // ── Medical / Health Data (multi-select checkbox → JSON array of strings) ─
    /// <summary>Current medical conditions selected from a checkbox list on the Google Form.</summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<string>? PresentMedicalConditions { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<string>? PastMedicalHistory { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<string>? ImmunizationHistory { get; set; }

    // ── Family Health History (free text) ────────────────────────────────────
    /// <summary>
    /// Family-side medical conditions (free text). The Google Form may label this differently
    /// (e.g. "Family Medical History"), but this property name matches the entity column
    /// FamilyMedicalConditionsNotes for clean round-trip mapping.
    /// </summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? FamilyMedicalConditionsNotes { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? OngoingMedications { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? DevelopmentalConditions { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? OtherMedicalDiagnosis { get; set; }

    /// <summary>Supports payloads where contacts array was nested inside the form object.</summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<ResponseContactDto>? Contacts { get; set; }
}

/// <summary>
/// Contact item matching the expanded Contact table schema.
/// Supports Father (RelationType=1), Mother (2), and Guardian (3) as separate entries
/// in the Contacts list — no structural change needed, the list already handles multiple contacts.
/// </summary>
public class ResponseContactDto
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;

    /// <summary>Lookup ID matching Contact.RelationType (int, e.g. 1 = Father, 2 = Mother, 3 = Guardian).</summary>
    [JsonConverter(typeof(RelationTypeJsonConverter))]
    public int RelationType { get; set; }

    /// <summary>Nullable — the new form does not require occupation for all contact types.</summary>
    public string? Occupation { get; set; }
    public string ContactNo { get; set; } = string.Empty;

    // ── Extended contact fields (new) ────────────────────────────────────────
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Email { get; set; }

    /// <summary>Contact date of birth. Stored as string from webhook (e.g. "1975-04-20") and parsed at mapping time.</summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? DateOfBirth { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Workplace { get; set; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? FacebookAccount { get; set; }

    /// <summary>Only meaningful when RelationType = 3 (Guardian). Null for Father/Mother.</summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? LivingWithGuardian { get; set; }

    /// <summary>Describes how a Guardian relates to the student (e.g. "Grandmother", "Sister", "Other"). Only meaningful when RelationType = 3 (Guardian).</summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? GuardianRelationshipDescription { get; set; }

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

// ShsStrandJsonConverter removed — SHSStrand (int lookup) replaced by ProgramTrackStrand (string?).
// The new Google Form sends free text; no int conversion is needed.

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
