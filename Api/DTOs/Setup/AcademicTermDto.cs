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

    /// <summary>When this term's grades were released to students, or null while withheld.</summary>
    public DateTime? GradesReleasedAt { get; set; }

    public bool AreGradesReleased { get; set; }

    /// <summary>
    /// Classes in this term whose grade sheet nobody has verified. Shown when releasing so the
    /// Registrar can see what is going out unchecked; it does not stop her.
    /// </summary>
    public int UnverifiedSheets { get; set; }
}
