using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;
using Api.Domain.Enrollment;

namespace Api.Domain.Grading;

public class Grade
{
    [Key]
    public Guid GradeID { get; set; }

    public Guid StudyLoadID { get; set; }
    public StudyLoad? StudyLoad { get; set; }

    public decimal? MidtermGrade { get; set; }
    public decimal? FinalGrade { get; set; }
    public int? Remarks { get; set; }

    public Guid SubmittedByUserID { get; set; }
    public User? SubmittedByUser { get; set; }

    public DateTime DateSubmitted { get; set; }
}
