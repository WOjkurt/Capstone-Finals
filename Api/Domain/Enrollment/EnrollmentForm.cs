using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain.Enrollment;

public class EnrollmentForm
{
    [Key]
    public Guid EnrollmentID { get; set; }

    public Guid ApplicationID { get; set; }
    public EnrollmentApplication? Application { get; set; }

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
    public required string CityMunicipality { get; set; }
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
    // YearLevel from the Google Form (required field). May be overridden by the registrar at approval time.
    public int YearLevel { get; set; }

    // New enrollment metadata
    public int? StudentType { get; set; }   // 1=New, 2=Old, 3=Transferee
    public string? LRN { get; set; }         // Learner Reference Number (Old/Transferee)
    public string? AcademicYear { get; set; } // e.g. "2026-2027"
    public string? IncomingCourse { get; set; } // Student-stated preference (e.g. "BSIT")

    // Optional: physical Student ID from a previous enrollment, stored for manual registrar reference only.
    public string? PreviousStudentID { get; set; }

    // ── Family Information ───────────────────────────────────────────────────
    public string? BirthOrder { get; set; }      // "Only" / "First" / "Second" / ... / "Other"
    public int? NumberOfSiblings { get; set; }
    public string? FamilyStatus { get; set; }     // "Separated" / "Both Present" / "Father Deceased" / etc.

    // ── Medical / Health Data (multi-select checkboxes → jsonb string arrays) ─
    [Column(TypeName = "jsonb")]
    public List<string>? FamilyMedicalConditionsSelected { get; set; }

    [Column(TypeName = "jsonb")]
    public List<string>? PastMedicalHistory { get; set; }

    [Column(TypeName = "jsonb")]
    public List<string>? ImmunizationHistory { get; set; }

    // ── Family Health History (free text) ────────────────────────────────────
    public string? FamilyMedicalConditionsNotes { get; set; }
    public string? OngoingMedications { get; set; }
    public string? DevelopmentalConditions { get; set; }
    public string? OtherMedicalDiagnosis { get; set; }
}
