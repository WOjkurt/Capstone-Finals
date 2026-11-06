using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

/// <summary>
/// School-wide values the Registrar can change. One row at most; with no row the defaults in
/// StudyLoadService apply.
/// </summary>
public class SchoolSettings
{
    public const int SingleId = 1;

    [Key]
    public int SettingsID { get; set; } = SingleId;

    public decimal SummerMaxUnits { get; set; }
    public decimal GraduatingSummerMaxUnits { get; set; }

    public Guid? UpdatedByUserID { get; set; }
    public DateTime UpdatedAt { get; set; }
}
