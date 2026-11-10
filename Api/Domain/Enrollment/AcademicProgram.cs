using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

public class AcademicProgram
{
    [Key]
    public int ProgramID { get; set; }
    public required string ProgramCode { get; set; }
    public required string ProgramName { get; set; }

    /// <summary>Optional, e.g. "Mechanical Technology". Each major is its own program because it has its own curricula.</summary>
    [MaxLength(100)]
    public string? Major { get; set; }

    /// <summary>"Bachelor of …, Major in Mechanical Technology" for records and printouts.</summary>
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string FullName => FullNameOf(ProgramName, Major);

    public static string FullNameOf(string name, string? major) =>
        string.IsNullOrWhiteSpace(major) ? name : $"{name}, Major in {major.Trim()}";
}
