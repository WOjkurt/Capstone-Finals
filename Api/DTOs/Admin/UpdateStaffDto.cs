using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Admin;

public class UpdateStaffDto
{
    [StringLength(100, MinimumLength = 1)]
    [RegularExpression(@"^[\p{L}\p{M}\s\-'’\.]+$")]
    public string? Firstname { get; set; }

    [StringLength(100, MinimumLength = 1)]
    [RegularExpression(@"^[\p{L}\p{M}\s\-'’\.]+$")]
    public string? Lastname { get; set; }

    [Range(1, 6)]
    public int? Role { get; set; }

    [Range(1, int.MaxValue)]
    public int? EmployeeID { get; set; }

    public Guid? PositionID { get; set; }

    [Range(1, int.MaxValue)]
    public int? ProgramID { get; set; }

    public bool? IsRegular { get; set; }
}
