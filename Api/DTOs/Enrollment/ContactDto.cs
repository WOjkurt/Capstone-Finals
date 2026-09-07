namespace Api.DTOs.Enrollment;

public class ContactDto
{
    public required string FirstName { get; set; }
    public required string LastName { get; set; }
    public int RelationType { get; set; }
    public required string Occupation { get; set; }
    public required string ContactNo { get; set; }
}
