using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Credits;

public class AccreditedSchoolDto
{
    public Guid SchoolId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Address { get; set; }
    /// <summary>How many credited subjects name this school.</summary>
    public int CreditCount { get; set; }
}

public class SaveAccreditedSchoolDto
{
    [Required, MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(300)]
    public string? Address { get; set; }
}

/// <summary>A school name used on credits that is not on the accredited list yet.</summary>
public class UnlistedSchoolDto
{
    public string Name { get; set; } = string.Empty;
    public int CreditCount { get; set; }
}
