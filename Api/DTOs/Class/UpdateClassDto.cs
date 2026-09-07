namespace Api.DTOs.Class;

public class UpdateClassDto
{
    public Guid? UserID { get; set; }
    public required string ClassName { get; set; }
}
