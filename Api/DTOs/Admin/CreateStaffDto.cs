using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Admin;

public class CreateStaffDto
{
    [Required]
    [StringLength(320)]
    [EmailAddress]
    [RegularExpression(@"(?i).*@dbtc-cebu\.edu\.ph\z", ErrorMessage = "Email must be a @dbtc-cebu.edu.ph address.")]
    public required string Email { get; set; }

    [Required]
    [StringLength(100, MinimumLength = 1)]
    [Api.Common.PersonName]
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.PlainNameConverter))]
    public required string Firstname { get; set; }

    [Required]
    [StringLength(100, MinimumLength = 1)]
    [Api.Common.PersonName]
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.PlainNameConverter))]
    public required string Lastname { get; set; }

    [Required]
    [Range(1, 6)]
    public int Role { get; set; }

    [Range(1, int.MaxValue)]
    public int? EmployeeID { get; set; }

    public Guid? PositionID { get; set; }

    [Range(1, int.MaxValue)]
    public int? ProgramID { get; set; }

    public bool? IsRegular { get; set; } = true;
}
