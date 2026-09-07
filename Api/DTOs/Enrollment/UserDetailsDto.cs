namespace Api.DTOs.Enrollment;

public class UserDetailsDto
{
    public Guid UserDetailID { get; set; }
    public Guid UserID { get; set; }
    public string Firstname { get; set; } = string.Empty;
    public string Lastname { get; set; } = string.Empty;
    public string? LRN { get; set; }
    public int? ProgramID { get; set; }
    public int? StudentType { get; set; }
    public int? StudentStatus { get; set; }
    public int? YearLevel { get; set; }
    public int? EmployeeID { get; set; }
    public Guid? PositionID { get; set; }
    public bool IsRegular { get; set; }
}
