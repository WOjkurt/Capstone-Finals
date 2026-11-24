using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;

namespace Api.Domain.Enrollment;

public class Class
{
    [Key]
    public Guid ClassID { get; set; }

    public Guid SubjectID { get; set; }
    public Subject? Subject { get; set; }

    public Guid? UserID { get; set; }
    public User? User { get; set; }

    public Guid TermID { get; set; }
    public AcademicTerm? Term { get; set; }

    public required string ClassName { get; set; }

    public DateTime CreatedAt { get; set; }

    public Guid? CreatedByUserID { get; set; }
    public User? CreatedByUser { get; set; }

    public ICollection<ClassSchedule> ClassSchedules { get; set; } = new List<ClassSchedule>();

    // ── Grade sheet verification ─────────────────────────────────────────
    // A Program Head checking the marks before the term's results go out. It says somebody
    // other than the person who can change a grade has looked at this class's sheet.

    /// <summary>When the sheet was last verified. Null means nobody has checked it.</summary>
    public DateTime? VerifiedAt { get; set; }

    public Guid? VerifiedByUserID { get; set; }
    public Api.Domain.IdentityAccess.User? VerifiedByUser { get; set; }
}
