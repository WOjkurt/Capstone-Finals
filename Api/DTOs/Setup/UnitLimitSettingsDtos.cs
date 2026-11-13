namespace Api.DTOs.Setup;

public class UnitLimitSettingsDto
{
    public decimal SummerMaxUnits { get; set; }
    public decimal GraduatingSummerMaxUnits { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class SaveUnitLimitSettingsDto
{
    public decimal SummerMaxUnits { get; set; }
    public decimal GraduatingSummerMaxUnits { get; set; }
}

/// <summary>Setup → Dean's list rules. Units are always the student's regular study load.</summary>
public class DeansListRulesDto
{
    public decimal MaxGwa { get; set; }
    public decimal WorstGrade { get; set; }
    public string? UpdatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class SaveDeansListRulesDto
{
    public decimal MaxGwa { get; set; }
    public decimal WorstGrade { get; set; }
}
