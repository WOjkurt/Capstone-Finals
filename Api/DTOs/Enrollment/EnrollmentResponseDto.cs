namespace Api.DTOs.Enrollment;

/// <summary>
/// Response payload returned to the Registrar when viewing an enrollment response.
/// Data contains the parsed applicant submission used to pre-fill the review form.
/// </summary>
public class EnrollmentResponseDto
{
    public Guid ResponseID { get; set; }
    public DateTime Timestamp { get; set; }
    public required string EmailAddress { get; set; }
    public bool IsProcessed { get; set; }

    /// <summary>
    /// Parsed form data and contacts from the applicant submission.
    /// Mirrored directly from the jsonb column.
    /// </summary>
    public ResponseDataDto? Data { get; set; }
}
