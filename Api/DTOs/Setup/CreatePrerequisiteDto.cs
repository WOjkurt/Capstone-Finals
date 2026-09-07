namespace Api.DTOs.Setup;

public class CreatePrerequisiteDto
{
    public Guid SubjectID { get; set; }
    public Guid PrerequisiteSubjectID { get; set; }
    public int RequisiteType { get; set; }
}
