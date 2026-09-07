namespace Api.DTOs.StudyLoad;

public class ClassOptionDto
{
    public Guid ClassId { get; set; }
    public required string ClassName { get; set; }
    public string? TeacherName { get; set; }
    public required string Schedule { get; set; }
}
