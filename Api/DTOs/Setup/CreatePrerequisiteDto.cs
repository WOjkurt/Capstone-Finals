using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Setup;

public class CreatePrerequisiteDto
{
    public Guid SubjectID { get; set; }
    public Guid PrerequisiteSubjectID { get; set; }

    /// <summary>
    /// 0 = Prerequisite (must be passed before enrolling).
    /// 1 = Corequisite (must be taken concurrently in the same term).
    /// The client sends this field; it defaults to 0 when omitted.
    /// </summary>
    [Range(0, 1, ErrorMessage = "RequisiteType must be 0 (Prerequisite) or 1 (Corequisite).")]
    public int RequisiteType { get; set; }
}
