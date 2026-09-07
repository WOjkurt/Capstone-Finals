using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

public class AcademicTerm
{
    [Key]
    public Guid TermID { get; set; }
    public required string SchoolYear { get; set; }
    public int Semester { get; set; }
}
