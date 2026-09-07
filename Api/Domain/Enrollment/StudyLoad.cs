using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;

namespace Api.Domain.Enrollment;

public class StudyLoad
{
    [Key]
    public Guid StudyLoadID { get; set; }

    public Guid UserID { get; set; }
    public User? User { get; set; }

    public Guid ClassID { get; set; }
    public Class? Class { get; set; }

    public int LoadStatus { get; set; }

    public DateTime CreatedAt { get; set; }

    public Guid? CreatedByUserID { get; set; }
    public User? CreatedByUser { get; set; }
}
