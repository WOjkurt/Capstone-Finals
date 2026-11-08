namespace Api.DTOs.Setup;

public class AcademicTermDto
{
    public Guid TermID { get; set; }
    public required string SchoolYear { get; set; }
    public int Semester { get; set; }
    public bool IsActive { get; set; }
    public DateOnly? EnrollmentOpensOn { get; set; }
    public DateOnly? EnrollmentClosesOn { get; set; }

    /// <summary>True when today (Philippine time) is between the two enrollment dates.</summary>
    public bool IsEnrollmentOpen { get; set; }
}
