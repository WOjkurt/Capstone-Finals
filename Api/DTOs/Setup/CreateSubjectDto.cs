using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Setup;

public class CreateSubjectDto
{
    public required string SubjectCode { get; set; }
    public required string SubjectTitle { get; set; }
    public decimal LecUnits { get; set; }
    public decimal LabUnits { get; set; }
    public decimal LecHours { get; set; }
    public decimal LabHours { get; set; }
    public int ProgramID { get; set; }
    public int YearLevel { get; set; }

    /// <summary>1 = 1st Semester, 2 = 2nd Semester, 3 = Summer Term.</summary>
    [Range(1, 3, ErrorMessage = "DefaultSemester must be 1 (1st Semester), 2 (2nd Semester), or 3 (Summer Term).")]
    public int DefaultSemester { get; set; }

    /// <summary>Optional standing requirement (valid values: 1 to 4).</summary>
    [Range(1, 4, ErrorMessage = "StandingYear must be between 1 and 4.")]
    public int? StandingYear { get; set; }

    /// <summary>Minor (GE, theology…) subject. Null leaves an existing subject unchanged and makes a new one major.</summary>
    public bool? IsMinor { get; set; }
}
