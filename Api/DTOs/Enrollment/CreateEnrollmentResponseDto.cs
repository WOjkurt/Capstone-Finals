using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Enrollment;

/// <summary>
/// Payload posted by the Google Forms Apps Script webhook when a new enrollment
/// form is submitted. EmailAddress is stored as a top-level column; everything else
/// is serialized to the Data (jsonb) column so the Registrar can review it at
/// processing time without needing to retype anything.
/// </summary>
public class CreateEnrollmentResponseDto
{
    [Required]
    [StringLength(320)]
    public required string EmailAddress { get; set; }

    /// <summary>Full form data submitted by the applicant.</summary>
    public ResponseFormDataDto? Form { get; set; }

    /// <summary>
    /// Emergency/guardian contacts submitted by the applicant.
    /// Accepted at root level as well as within Form.
    /// </summary>
    public List<ResponseContactDto> Contacts { get; set; } = [];
}
