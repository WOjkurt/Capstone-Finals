using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Setup;

public class CreatePrerequisiteDto
{
    public Guid SubjectID { get; set; }
    public Guid PrerequisiteSubjectID { get; set; }
    // RequisiteType intentionally has no [Range] — the Flutter client never sends this
    // field, so it defaults to 0. The field is stored as-is for future use.
    public int RequisiteType { get; set; }
}
