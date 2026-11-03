using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Credits;

public class CreateCreditedSubjectDto
{
    public Guid UserId { get; set; }
    public Guid SubjectId { get; set; }

    [Required, MaxLength(200)]
    public string SourceSchool { get; set; } = string.Empty;

    [MaxLength(50)]
    public string? SourceSubjectCode { get; set; }

    [MaxLength(20)]
    public string? Grade { get; set; }

    [MaxLength(20)]
    public string? SchoolYear { get; set; }
}

public class CreditedSubjectDto
{
    public Guid CreditedSubjectId { get; set; }
    public Guid UserId { get; set; }
    public Guid SubjectId { get; set; }
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public decimal Units { get; set; }
    public int YearLevel { get; set; }
    public string SourceSchool { get; set; } = string.Empty;
    public string? SourceSubjectCode { get; set; }
    public string? Grade { get; set; }
    public string? SchoolYear { get; set; }
    public string? RecordedBy { get; set; }
    public DateTime RecordedAt { get; set; }
}
