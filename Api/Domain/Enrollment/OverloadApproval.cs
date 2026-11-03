using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;

namespace Api.Domain.Enrollment;

/// <summary>
/// Who approved a student's load going over the CHED unit limit in a term, and why. One row per student per term;
/// a later approval for the same term replaces it.
/// </summary>
public class OverloadApproval
{
    [Key]
    public Guid OverloadApprovalID { get; set; }

    public Guid UserID { get; set; }
    public User? User { get; set; }

    public Guid TermID { get; set; }
    public AcademicTerm? Term { get; set; }

    /// <summary>Units in the term after the approved save.</summary>
    public decimal Units { get; set; }
    public decimal MaxUnits { get; set; }

    [MaxLength(Api.Constants.ValidationConstants.NotesMax)]
    public required string Reason { get; set; }

    public Guid ApprovedByUserID { get; set; }
    public User? ApprovedByUser { get; set; }

    public DateTime ApprovedAt { get; set; }
}
