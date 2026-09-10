namespace Api.DTOs.Admin;

public class StaffResponseDto
{
    public Guid UserID { get; set; }
    public string FirebaseUID { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public int Role { get; set; }
    public string RoleName { get; set; } = string.Empty;
    public string Firstname { get; set; } = string.Empty;
    public string Lastname { get; set; } = string.Empty;
    public int? EmployeeID { get; set; }
    public Guid? PositionID { get; set; }
    public string? PositionName { get; set; }
    public int? ProgramID { get; set; }
    public string? ProgramCode { get; set; }
    public bool IsRegular { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? PasswordResetLink { get; set; }
    public string? FirebaseSyncWarning { get; set; }
}
