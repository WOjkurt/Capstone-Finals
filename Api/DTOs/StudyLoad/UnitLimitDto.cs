namespace Api.DTOs.StudyLoad;

/// <summary>
/// CHED-style unit limit for one student in one term. A warning only: the Registrar may go over it.
/// Regular semester: the curriculum load of the student's year and semester (21 if none), +6 when graduating.
/// Summer: 9 units, 12 when graduating.
/// </summary>
public class UnitLimitDto
{
    public decimal MaxUnits { get; set; }
    /// <summary>Units already Enrolled or Pending for the student in this term.</summary>
    public decimal CurrentUnits { get; set; }
    /// <summary>Summer only: units of retaken failed subjects in this term, left out of <see cref="CurrentUnits"/>.</summary>
    public decimal RetakeUnits { get; set; }
    /// <summary>True in summer: retakes of failed subjects are extra and don't count toward <see cref="MaxUnits"/>.</summary>
    public bool RetakesOutsideLimit { get; set; }
    public decimal CurriculumUnits { get; set; }
    public bool IsGraduating { get; set; }
    public bool IsSummer { get; set; }
    public string Rule { get; set; } = string.Empty;

    public bool IsOverloaded => CurrentUnits > MaxUnits;
    // The recorded overload approval for this term, if any.
    public string? OverloadReason { get; set; }
    public string? OverloadApprovedBy { get; set; }
    public DateTime? OverloadApprovedAt { get; set; }
}
