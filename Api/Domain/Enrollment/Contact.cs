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
    public int RelationType { get; set; }
    public required string Occupation { get; set; }
    public required string ContactNo { get; set; }
}
