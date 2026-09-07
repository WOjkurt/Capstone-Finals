namespace Api.DTOs.Enrollment;

public class CreateEnrollmentApplicationDto
{
    public Guid ResponseID { get; set; }
    public int ProgramID { get; set; }
    public Guid TermID { get; set; }

    public required EnrollmentFormDto Form { get; set; }
    public List<ContactDto> Contacts { get; set; } = new();
}
