namespace Api.DTOs.Admin;

public class UpdateStaffDto
{
    public string? Firstname { get; set; }

    public string? Lastname { get; set; }

    public int? Role { get; set; }

    public int? EmployeeID { get; set; }

    public Guid? PositionID { get; set; }

    public int? ProgramID { get; set; }

    public bool? IsRegular { get; set; }
}
