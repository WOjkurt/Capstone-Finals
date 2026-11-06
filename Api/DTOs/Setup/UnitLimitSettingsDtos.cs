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
