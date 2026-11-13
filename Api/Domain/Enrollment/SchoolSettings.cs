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

    /// <summary>Dean's list: highest GWA that qualifies. Null = DBTC's 1.7.</summary>
    public decimal? DeansListMaxGwa { get; set; }
    /// <summary>Dean's list: no subject grade may be higher (worse) than this. Null = DBTC's 2.3.</summary>
    public decimal? DeansListWorstGrade { get; set; }

    public Guid? UpdatedByUserID { get; set; }
    public DateTime UpdatedAt { get; set; }
}
