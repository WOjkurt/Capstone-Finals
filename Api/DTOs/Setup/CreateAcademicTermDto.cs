namespace Api.DTOs.Setup;

public class CreateAcademicTermDto
{
    public required string SchoolYear { get; set; }
    public int Semester { get; set; }
}
