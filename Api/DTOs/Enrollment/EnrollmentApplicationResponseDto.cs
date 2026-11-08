namespace Api.DTOs.Enrollment;

public class EnrollmentApplicationResponseDto
{
    public Guid ApplicationID { get; set; }
    public Guid ResponseID { get; set; }
    public int ProgramID { get; set; }
    public Guid TermID { get; set; }
    // 1 = Pending, 2 = Approved, 3 = Rejected, 4 = Active
    public int Status { get; set; }
    public Guid? ReviewedByUserID { get; set; }
    public Guid? StudentUserID { get; set; }
    public DateTime CreatedAt { get; set; }
    public Guid? CreatedByUserID { get; set; }
    public string? SchoolEmail { get; set; }

    /// <summary>An old student who enrolled again from the Student Portal.</summary>
    public bool IsReturning { get; set; }

    /// <summary>What a returning student changed since their last enrollment.</summary>
    public List<string> ChangedFields { get; set; } = new();

    public EnrollmentFormDto? Form { get; set; }
    public List<ContactDto> Contacts { get; set; } = new();
    public UserDetailsDto? UserDetails { get; set; }
}
