using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

public class EnrollmentForm
{
    [Key]
    public Guid EnrollmentID { get; set; }

    public Guid ApplicationID { get; set; }
    public EnrollmentApplication? Application { get; set; }

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
    public required string CityMunicipality { get; set; }
    public required string Province { get; set; }
    public required string ZipCode { get; set; }

    public required string LastSchoolAttended { get; set; }
    public required string SchoolAddress { get; set; }
    public int SHSStrand { get; set; }
    public DateOnly YearGraduated { get; set; }
    public required string PreviousCollege { get; set; }
    public required string PreviousCourse { get; set; }

    // YearLevel from the Google Form (required field). May be overridden by the registrar at approval time.
    public int YearLevel { get; set; }

    // Optional: physical Student ID from a previous enrollment, stored for manual registrar reference only.
    public string? PreviousStudentID { get; set; }
}
