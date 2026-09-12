using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

public class Contact
{
    [Key]
    public Guid ContactID { get; set; }

    public Guid EnrollmentID { get; set; }
    public EnrollmentForm? EnrollmentForm { get; set; }

    public required string FirstName { get; set; }
    public required string LastName { get; set; }

    /// <summary>Lookup ID: 1 = Father, 2 = Mother, 3 = Guardian.</summary>
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

    /// <summary>Describes how a Guardian relates to the student (e.g. "Grandmother", "Sister", "Other"). Only meaningful when RelationType = 3 (Guardian); null for Father/Mother.</summary>
    public string? GuardianRelationshipDescription { get; set; }
}
