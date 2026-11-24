using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Grading;

/// <summary>
/// The Registrar changing a grade that is already recorded.
///
/// This replaces the correction request, where somebody asked and somebody else approved. With
/// almost every class having no teacher, there was nobody to do the asking, so in practice the
/// Registrar raised the request and approved it herself — two steps that only ever had one
/// person in them.
///
/// A reason is required. It is the only thing separating a correction from a quiet rewrite of a
/// student's record, and it is what the activity log will carry alongside the old and new marks.
/// </summary>
public class ModifyGradeDto
{
    /// <summary>Null leaves the midterm as it is. Both may be sent together.</summary>
    public decimal? MidtermGrade { get; set; }

    /// <summary>Null leaves the final as it is. Changing it re-decides passed or failed.</summary>
    public decimal? FinalGrade { get; set; }

    [Required(ErrorMessage = "Say why the grade is being changed.")]
    [MaxLength(300)]
    public string Reason { get; set; } = string.Empty;
}
