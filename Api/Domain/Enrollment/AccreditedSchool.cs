using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

/// <summary>
/// A school DBTC accepts credits from. The Registrar picks from this list when recording credits,
/// so the same school is always spelled the same way.
/// </summary>
public class AccreditedSchool
{
    [Key]
    public Guid SchoolID { get; set; }

    [MaxLength(200)]
    public required string Name { get; set; }

    [MaxLength(300)]
    public string? Address { get; set; }

    public DateTime CreatedAt { get; set; }
}
