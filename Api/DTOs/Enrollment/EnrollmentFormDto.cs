namespace Api.DTOs.Enrollment;

public class EnrollmentFormDto
{
    public required string FirstName { get; set; }
    public required string MiddleName { get; set; }
    public required string LastName { get; set; }
    public required string Suffix { get; set; }

    public DateOnly DateOfBirth { get; set; }
    public required string PlaceOfBirth { get; set; }
    public required string Sex { get; set; }
    public required string CivilStatus { get; set; }
    public required string Nationality { get; set; }

    public required string MobileNumber { get; set; }
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

    public required string LastSchoolAttended { get; set; }
    public required string SchoolAddress { get; set; }
    public int SHSStrand { get; set; }
    public DateOnly YearGraduated { get; set; }
    public required string PreviousCollege { get; set; }
    public required string PreviousCourse { get; set; }

    // Required field from the Google Form. The registrar may override this at approval time.
    public int YearLevel { get; set; }

    // Optional: physical Student ID from a previous enrollment.
    public string? PreviousStudentID { get; set; }
}
