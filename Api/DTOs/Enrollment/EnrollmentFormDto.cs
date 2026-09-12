namespace Api.DTOs.Enrollment;

public class EnrollmentFormDto
{
    // ── Name ────────────────────────────────────────────────────────────────
    public required string FirstName { get; set; }
    public required string MiddleName { get; set; }
    public required string LastName { get; set; }
    public required string Suffix { get; set; }

    // ── Personal Information ─────────────────────────────────────────────────
    public DateOnly DateOfBirth { get; set; }
    public required string PlaceOfBirth { get; set; }
    public required string Sex { get; set; }
    public required string CivilStatus { get; set; }
    public required string Nationality { get; set; }

    // New personal fields
    public string? Gender { get; set; }
    public int? Age { get; set; }
    public string? BloodType { get; set; }
    public string? Religion { get; set; }
    public string? FacebookName { get; set; }

    // ── Primary Address ──────────────────────────────────────────────────────
    public required string MobileNumber { get; set; }
    public string? HouseStreet { get; set; }
    public required string Barangay { get; set; }

    [System.Text.Json.Serialization.JsonPropertyName("cityMunicipality")]
    public string CityMunicipality { get; set; } = string.Empty;

    [System.Text.Json.Serialization.JsonPropertyName("cityOfMunicipality")]
    public string? CityOfMunicipality
    {
        get => CityMunicipality;
        set { if (!string.IsNullOrEmpty(value)) CityMunicipality = value; }
    }

    public required string Province { get; set; }
    public required string ZipCode { get; set; }

    // ── Secondary / Provincial Address (optional) ────────────────────────────
    public string? ProvHouseStreet { get; set; }
    public string? ProvBarangay { get; set; }
    public string? ProvCityMunicipality { get; set; }
    public string? ProvProvince { get; set; }
    public string? ProvZipCode { get; set; }

    // ── Educational Background ───────────────────────────────────────────────
    public required string LastSchoolAttended { get; set; }
    public required string SchoolAddress { get; set; }
    public string? ProgramTrackStrand { get; set; }
    public DateOnly YearGraduated { get; set; }
    public required string PreviousCollege { get; set; }
    public required string PreviousCourse { get; set; }

    // ── Enrollment Metadata ──────────────────────────────────────────────────
    // Required field from the Google Form. The registrar may override this at approval time.
    public int YearLevel { get; set; }

    public int? StudentType { get; set; }    // 1=New, 2=Old, 3=Transferee
    public string? LRN { get; set; }
    public string? AcademicYear { get; set; }
    public string? IncomingCourse { get; set; }

    // Optional: physical Student ID from a previous enrollment.
    public string? PreviousStudentID { get; set; }

    // ── Family Information ───────────────────────────────────────────────────
    public string? BirthOrder { get; set; }
    public int? NumberOfSiblings { get; set; }
    public string? FamilyStatus { get; set; }

    // ── Medical / Health Data (multi-select checkboxes → JSON arrays) ────────
    public List<string>? FamilyMedicalConditionsSelected { get; set; }
    public List<string>? PastMedicalHistory { get; set; }
    public List<string>? ImmunizationHistory { get; set; }

    // ── Family Health History (free text) ────────────────────────────────────
    public string? FamilyMedicalConditionsNotes { get; set; }
    public string? OngoingMedications { get; set; }
    public string? DevelopmentalConditions { get; set; }
    public string? OtherMedicalDiagnosis { get; set; }
}
