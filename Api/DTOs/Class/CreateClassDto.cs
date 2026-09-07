namespace Api.DTOs.Class;

public class CreateClassDto
{
    public Guid SubjectID { get; set; }
    public Guid? UserID { get; set; }
    public Guid TermID { get; set; }
    public required string ClassName { get; set; }
}
