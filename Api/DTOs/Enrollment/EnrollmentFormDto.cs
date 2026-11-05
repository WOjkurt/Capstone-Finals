using System.ComponentModel.DataAnnotations;
using Api.Constants;

namespace Api.DTOs.Enrollment;

public class EnrollmentFormDto
{
    // ── Name ────────────────────────────────────────────────────────────────
    [Required]
    [StringLength(ValidationConstants.NameMax)]
    public required string FirstName { get; set; }
    [Required]
    [StringLength(ValidationConstants.ShortMax)]
    public required string MiddleName { get; set; }
    [Required]
    [StringLength(ValidationConstants.NameMax)]
    public required string LastName { get; set; }
    [Required]
    [StringLength(ValidationConstants.ShortMax)]
    public required string Suffix { get; set; }

    // ── Personal Information ─────────────────────────────────────────────────
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.FlexibleDateConverter))]
    public DateOnly DateOfBirth { get; set; }
    [Required]
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
    public string? ProvZipCode { get; set; }

    // ── Educational Background ───────────────────────────────────────────────
    [Required]
    [StringLength(ValidationConstants.LongAddressMax)]
    public required string LastSchoolAttended { get; set; }
    [Required]
    [StringLength(ValidationConstants.LongAddressMax)]
    public required string SchoolAddress { get; set; }
    [StringLength(ValidationConstants.AddressMax)]
    public string? ProgramTrackStrand { get; set; }
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.FlexibleDateConverter))]
    public DateOnly YearGraduated { get; set; }
    [Required]
    [StringLength(ValidationConstants.AddressMax)]
    public required string PreviousCollege { get; set; }
    [Required]
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
