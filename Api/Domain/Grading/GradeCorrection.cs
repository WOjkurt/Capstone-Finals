using System.ComponentModel.DataAnnotations;
using Api.Domain.IdentityAccess;

namespace Api.Domain.Grading;

public class GradeCorrection
{
    [Key]
    public Guid CorrectionID { get; set; }

    public Guid GradeID { get; set; }
    public Grade? Grade { get; set; }

    public int CorrectionPeriod { get; set; }
    public decimal OldGrade { get; set; }
    public decimal NewGrade { get; set; }
    public required string Reason { get; set; }

    public Guid RequestedByUserID { get; set; }
    public User? RequestedByUser { get; set; }

    public Guid? ReviewedByUserID { get; set; }
    public User? ReviewedByUser { get; set; }

    public int CorrectionStatus { get; set; }
    public DateTime DateRequested { get; set; }
    public DateTime? DateReviewed { get; set; }
}
