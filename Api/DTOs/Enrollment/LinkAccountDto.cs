using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Enrollment;

public class LinkAccountDto
{
    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;
}
