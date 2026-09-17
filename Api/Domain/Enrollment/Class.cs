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
}
