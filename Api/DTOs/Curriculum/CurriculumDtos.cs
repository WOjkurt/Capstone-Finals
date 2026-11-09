using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Curriculum;

public class CurriculumDto
{
    public Guid CurriculumID { get; set; }
    public int ProgramID { get; set; }
    public string? ProgramCode { get; set; }
    public required string Name { get; set; }
    public int EffectiveFromYear { get; set; }
    /// <summary>"2026-2027": the school year it takes effect.</summary>
    public required string EffectiveSchoolYear { get; set; }
    public int SubjectCount { get; set; }
    public int StudentCount { get; set; }
    /// <summary>The program's newest curriculum: new students get this one.</summary>
    public bool IsNewest { get; set; }
}

public class SaveCurriculumDto
{
    /// <summary>Ignored on update (a curriculum never moves to another program).</summary>
    public int ProgramID { get; set; }

    [Required, StringLength(100, MinimumLength = 1)]
    public required string Name { get; set; }

    /// <summary>First year of the school year it takes effect, e.g. 2026 for SY 2026-2027.</summary>
    [Range(1990, 2100, ErrorMessage = "The effective school year must start between 1990 and 2100.")]
    public int EffectiveFromYear { get; set; }
}

public class SetStudentCurriculumDto
{
    public Guid CurriculumID { get; set; }
}

public class StudentCurriculumDto
{
    public int? ProgramID { get; set; }
    public Guid? CurriculumID { get; set; }
    public string? Name { get; set; }
    public string? EffectiveSchoolYear { get; set; }
}
