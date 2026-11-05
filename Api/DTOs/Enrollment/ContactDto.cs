using System.ComponentModel.DataAnnotations;
using Api.Constants;

namespace Api.DTOs.Enrollment;

public class ContactDto
{
    [Required]
    [StringLength(ValidationConstants.NameMax)]
    public required string FirstName { get; set; }
    [Required]
    [StringLength(ValidationConstants.NameMax)]
    public required string LastName { get; set; }

    /// <summary>1 = Father, 2 = Mother, 3 = Guardian.</summary>
    public int RelationType { get; set; }

    [StringLength(ValidationConstants.AddressMax)]
    public string? Occupation { get; set; }
    [Required]
    [StringLength(ValidationConstants.PhoneMax)]
    public required string ContactNo { get; set; }

    // ── Extended contact fields (new) ────────────────────────────────────────
    [StringLength(320)]
    public string? Email { get; set; }
    [System.Text.Json.Serialization.JsonConverter(typeof(Api.Common.FlexibleNullableDateConverter))]
    public DateOnly? DateOfBirth { get; set; }
    [StringLength(ValidationConstants.AddressMax)]
    public string? Workplace { get; set; }
    [StringLength(ValidationConstants.NameMax)]
    public string? FacebookAccount { get; set; }

    /// <summary>Only meaningful when RelationType = 3 (Guardian). Null for Father/Mother.</summary>
    public bool? LivingWithGuardian { get; set; }

    [StringLength(ValidationConstants.AddressMax)]
    public string? GuardianRelationshipDescription { get; set; }
}
