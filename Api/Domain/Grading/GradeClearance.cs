using System.ComponentModel.DataAnnotations;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;

namespace Api.Domain.Grading;

public class GradeClearance
{
    [Key]
    public Guid ClearanceID { get; set; }

    public Guid UserID { get; set; }
    public User? User { get; set; }

    public Guid TermID { get; set; }
    public AcademicTerm? Term { get; set; }

    public bool IsCleared { get; set; }

    public Guid? ClearedByUserID { get; set; }
    public User? ClearedByUser { get; set; }

    public DateTime? ClearedAt { get; set; }
}
