using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace Api.Domain.Enrollment;

public class EnrollmentResponse
{
    [Key]
    public Guid ResponseID { get; set; }
    public DateTime Timestamp { get; set; }
    public required string EmailAddress { get; set; }
    public bool IsProcessed { get; set; }

    /// <summary>
    /// Raw applicant-submitted form data, stored as jsonb.
    /// This is the pre-fill source for the Registrar's review step
    /// and is never used directly as EnrollmentForm/Contact table data.
    /// </summary>
    public JsonDocument? Data { get; set; }
}
