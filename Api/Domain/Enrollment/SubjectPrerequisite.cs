using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

public class SubjectPrerequisite
{
    [Key]
    public Guid PrerequisiteID { get; set; }

    public Guid SubjectID { get; set; }
    public Subject? Subject { get; set; }

    public Guid PrerequisiteSubjectID { get; set; }
    public Subject? PrerequisiteSubject { get; set; }

    public int RequisiteType { get; set; }
}
