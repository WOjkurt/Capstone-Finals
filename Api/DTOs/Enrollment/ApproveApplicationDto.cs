namespace Api.DTOs.Enrollment;

public class ApproveApplicationDto
{
    /// <summary>
    /// Optional registrar override for the student's year level.
    /// If provided, overwrites the value the student submitted on the form.
    /// If null, the form's original YearLevel is kept.
    /// </summary>
    public int? YearLevel { get; set; }
}
