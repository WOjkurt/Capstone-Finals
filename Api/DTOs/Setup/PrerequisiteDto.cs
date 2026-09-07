namespace Api.DTOs.Setup;

public class PrerequisiteDto
{
    public Guid PrerequisiteID { get; set; }
    public Guid SubjectID { get; set; }
    public Guid PrerequisiteSubjectID { get; set; }
    public string? PrerequisiteSubjectCode { get; set; }
    public string? PrerequisiteSubjectTitle { get; set; }
    public int RequisiteType { get; set; }
}
