using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

/// <summary>
/// One version of a program's subjects, for example the CHED curriculum that took effect in SY 2026-2027.
/// A student keeps the curriculum of their batch until they graduate; students who start in or after
/// <see cref="EffectiveFromYear"/> get the newest curriculum automatically.
/// </summary>
public class Curriculum
{
    [Key]
    public Guid CurriculumID { get; set; }

    public int ProgramID { get; set; }
    public AcademicProgram? Program { get; set; }

    [MaxLength(100)]
    public required string Name { get; set; }

    /// <summary>First year of the school year it takes effect, e.g. 2026 for SY 2026-2027.</summary>
    public int EffectiveFromYear { get; set; }

    public DateTime CreatedAt { get; set; }
}
