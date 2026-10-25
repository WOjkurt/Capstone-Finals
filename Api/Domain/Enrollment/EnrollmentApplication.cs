using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;

namespace Api.Domain.Enrollment;

public class EnrollmentApplication
{
    [Key]
    public Guid ApplicationID { get; set; }

    public Guid ResponseID { get; set; }
    public EnrollmentResponse? Response { get; set; }

    public int ProgramID { get; set; }
    public AcademicProgram? Program { get; set; }

    public Guid TermID { get; set; }
    public AcademicTerm? Term { get; set; }

    public int Status { get; set; }

    public Guid? ReviewedByUserID { get; set; }
    public User? ReviewedByUser { get; set; }

    public Guid? StudentUserID { get; set; }
    public User? StudentUser { get; set; }

    public string? SchoolEmail { get; set; }

    public DateTime CreatedAt { get; set; }

    public Guid? CreatedByUserID { get; set; }
    public User? CreatedByUser { get; set; }
}
