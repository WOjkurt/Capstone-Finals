namespace Api.DTOs.Setup;

public class AcademicTermDto
{
    public Guid TermID { get; set; }
    public required string SchoolYear { get; set; }
    public int Semester { get; set; }
    public bool IsActive { get; set; }
}
