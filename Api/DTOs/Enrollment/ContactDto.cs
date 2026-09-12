namespace Api.DTOs.Enrollment;

public class ContactDto
{
    public required string FirstName { get; set; }
    public required string LastName { get; set; }

    /// <summary>1 = Father, 2 = Mother, 3 = Guardian.</summary>
    public int RelationType { get; set; }

    public string? Occupation { get; set; }
    public required string ContactNo { get; set; }

    // ── Extended contact fields (new) ────────────────────────────────────────
    public string? Email { get; set; }
    public DateOnly? DateOfBirth { get; set; }
    public string? Workplace { get; set; }
    public string? FacebookAccount { get; set; }

    /// <summary>Only meaningful when RelationType = 3 (Guardian). Null for Father/Mother.</summary>
    public bool? LivingWithGuardian { get; set; }

    public string? GuardianRelationshipDescription { get; set; }
}
