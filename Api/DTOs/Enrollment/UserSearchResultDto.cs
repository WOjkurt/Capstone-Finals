namespace Api.DTOs.Enrollment;

public class UserSearchResultDto
{
    public Guid UserID { get; set; }
    public string Firstname { get; set; } = string.Empty;
    public string Lastname { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public int? ProgramID { get; set; }
    public string? ProgramCode { get; set; }
    public int? YearLevel { get; set; }
    public int? StudentStatus { get; set; }
    public int Role { get; set; }
    public string RoleName { get; set; } = string.Empty;
}
