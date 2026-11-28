using System.ComponentModel.DataAnnotations;
using Api.Constants;

namespace Api.DTOs.Enrollment;

public class EnrollmentFormDto
{
    // ── Locked fields may be empty ───────────────────────────────────────────
    // A field in ReenrollmentService.LockedFields is server-authoritative: whatever the client
    // sends is thrown away and the value is copied from the student's record. So an empty one
    // must not fail validation -- the student is shown the API's own payload and cannot edit
    // these, so a 400 here is a dead end with nothing to fix. Several are legitimately empty in
    // real records: the columns are NOT NULL, and '' is how "no suffix", "no middle name" and
    // "never went to college" are stored. Plain [Required] rejects '' as well as null, which
    // refused every such student's re-enrollment. AllowEmptyStrings still rejects null, so the
    // key must be present. FirstName, LastName and Sex stay strict on purpose: '' there is
    // broken data for the Registrar to repair, not something to wave through.
    // ── Name ────────────────────────────────────────────────────────────────
    [Required]
    [StringLength(ValidationConstants.NameMax)]
    [Api.Common.PersonName]
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.PlainNameConverter))]
    public required string FirstName { get; set; }
    [Required(AllowEmptyStrings = true)]
    [StringLength(ValidationConstants.ShortMax)]
    [Api.Common.PersonName]
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.PlainNameConverter))]
    public required string MiddleName { get; set; }
    [Required]
    [StringLength(ValidationConstants.NameMax)]
    [Api.Common.PersonName]
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.PlainNameConverter))]
    public required string LastName { get; set; }
    [Required(AllowEmptyStrings = true)]
    [StringLength(ValidationConstants.ShortMax)]
    [Api.Common.PersonName]
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.PlainNameConverter))]
    public required string Suffix { get; set; }

    // ── Personal Information ─────────────────────────────────────────────────
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.FlexibleDateConverter))]
    public DateOnly DateOfBirth { get; set; }
    [Required(AllowEmptyStrings = true)]
    [StringLength(ValidationConstants.AddressMax)]
    public required string PlaceOfBirth { get; set; }
    [Required]
    [StringLength(ValidationConstants.ShortMax)]
    public required string Sex { get; set; }
    [Required]
    [StringLength(ValidationConstants.ShortMax)]
    public required string CivilStatus { get; set; }
    [Required]
    [StringLength(ValidationConstants.ShortMax)]
    public required string Nationality { get; set; }

    // New personal fields
    [StringLength(ValidationConstants.ShortMax)]
    public string? Gender { get; set; }
    public int? Age { get; set; }
    [StringLength(ValidationConstants.ShortMax)]
    public string? BloodType { get; set; }
    [StringLength(ValidationConstants.ShortMax)]
    public string? Religion { get; set; }
    [StringLength(ValidationConstants.NameMax)]
    public string? FacebookName { get; set; }

    // ── Primary Address ──────────────────────────────────────────────────────
    [Required]
    [StringLength(ValidationConstants.PhoneMax)]
    [Api.Common.MobileNumber]
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.CleanPhoneConverter))]
    public required string MobileNumber { get; set; }
    [StringLength(ValidationConstants.LongAddressMax)]
    public string? HouseStreet { get; set; }
    [Required]
    [StringLength(ValidationConstants.AddressMax)]
    public required string Barangay { get; set; }

    [System.Text.Json.Serialization.JsonPropertyName("cityMunicipality")]
    public string CityMunicipality { get; set; } = string.Empty;

    [System.Text.Json.Serialization.JsonPropertyName("cityOfMunicipality")]
    public string? CityOfMunicipality
    {
        get => CityMunicipality;
        set { if (!string.IsNullOrEmpty(value)) CityMunicipality = value; }
    }

    [Required]
    [StringLength(ValidationConstants.AddressMax)]
    public required string Province { get; set; }
    [Required]
    [StringLength(ValidationConstants.ZipCodeMax)]
    [Api.Common.ZipCode]
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.CleanZipConverter))]
    public required string ZipCode { get; set; }

    // ── Secondary / Provincial Address (optional) ────────────────────────────
    [StringLength(ValidationConstants.AddressMax)]
    public string? ProvHouseStreet { get; set; }
    [StringLength(ValidationConstants.AddressMax)]
    public string? ProvBarangay { get; set; }
    [StringLength(ValidationConstants.AddressMax)]
    public string? ProvCityMunicipality { get; set; }
    [StringLength(ValidationConstants.AddressMax)]
    public string? ProvProvince { get; set; }
    [StringLength(ValidationConstants.AddressMax)]
    [Api.Common.ZipCode]
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.CleanZipConverter))]
    public string? ProvZipCode { get; set; }

    // ── Educational Background ───────────────────────────────────────────────
    [Required]
    [StringLength(ValidationConstants.LongAddressMax)]
    public required string LastSchoolAttended { get; set; }
    [Required(AllowEmptyStrings = true)]
    [StringLength(ValidationConstants.LongAddressMax)]
    public required string SchoolAddress { get; set; }
    [StringLength(ValidationConstants.AddressMax)]
    public string? ProgramTrackStrand { get; set; }
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.FlexibleDateConverter))]
    public DateOnly YearGraduated { get; set; }
    [Required(AllowEmptyStrings = true)]
    [StringLength(ValidationConstants.AddressMax)]
    public required string PreviousCollege { get; set; }
    [Required(AllowEmptyStrings = true)]
    [StringLength(ValidationConstants.AddressMax)]
    public required string PreviousCourse { get; set; }

    // ── Enrollment Metadata ──────────────────────────────────────────────────
    // Required field from the Google Form. The registrar may override this at approval time.
    public int YearLevel { get; set; }

    public int? StudentType { get; set; }    // 1=New, 2=Old, 3=Transferee
    [StringLength(ValidationConstants.ShortMax)]
    public string? LRN { get; set; }
    [StringLength(ValidationConstants.DateStringMax)]
    public string? AcademicYear { get; set; }
    [StringLength(ValidationConstants.AddressMax)]
    public string? IncomingCourse { get; set; }

    // Optional: physical Student ID from a previous enrollment.
    [StringLength(ValidationConstants.ShortMax)]
    public string? PreviousStudentID { get; set; }

    // ── Family Information ───────────────────────────────────────────────────
    [StringLength(ValidationConstants.ShortMax)]
    public string? BirthOrder { get; set; }
    public int? NumberOfSiblings { get; set; }
    [StringLength(ValidationConstants.ShortMax)]
    public string? FamilyStatus { get; set; }

    // ── Medical / Health Data (multi-select checkboxes → JSON arrays) ────────
    public List<string>? FamilyMedicalConditionsSelected { get; set; }
    public List<string>? PastMedicalHistory { get; set; }
    public List<string>? ImmunizationHistory { get; set; }

    // ── Family Health History (free text) ────────────────────────────────────
    [StringLength(ValidationConstants.NotesMax)]
    public string? FamilyMedicalConditionsNotes { get; set; }
    [StringLength(ValidationConstants.NotesMax)]
    public string? OngoingMedications { get; set; }
    [StringLength(ValidationConstants.NotesMax)]
    public string? DevelopmentalConditions { get; set; }
    [StringLength(ValidationConstants.NotesMax)]
    public string? OtherMedicalDiagnosis { get; set; }
}
