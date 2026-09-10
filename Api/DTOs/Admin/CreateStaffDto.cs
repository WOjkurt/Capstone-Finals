using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Admin;

public class CreateStaffDto
{
    [Required]
    [EmailAddress]
    public required string Email { get; set; }

    [Required]
    public required string Firstname { get; set; }

    [Required]
    public required string Lastname { get; set; }

    [Required]
    public int Role { get; set; }

    public int? EmployeeID { get; set; }

    public Guid? PositionID { get; set; }

    public int? ProgramID { get; set; }

    public bool? IsRegular { get; set; } = true;
}
