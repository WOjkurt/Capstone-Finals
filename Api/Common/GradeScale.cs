namespace Api.Common;

/// <summary>
/// DBTC-Cebu collegiate grades: 1.0 to 5.0 in steps of 0.1, plus the quarter steps (1.25, 1.75, …).
/// 3.0 and below is Passed; above 3.0 is Failed.
/// </summary>
public static class GradeScale
{
    public const decimal Min = 1.0m;
    public const decimal Max = 5.0m;
    public const decimal PassingMax = 3.0m;

    public const string Description = "Grades must be from 1.0 to 5.0 in steps of 0.1 (1.25, 1.75 … are also allowed).";

    public static bool IsValid(decimal value)
    {
        if (value < Min || value > Max) return false;
        decimal hundredths = value * 100m;
        return hundredths % 10m == 0m || hundredths % 25m == 0m;
    }

    public static void EnsureValid(decimal? value)
    {
        if (value.HasValue && !IsValid(value.Value))
        {
            throw new InvalidOperationException($"{value.Value:0.0#} is not a valid grade. {Description}");
        }
    }

    public static int Remarks(decimal finalGrade) => finalGrade > PassingMax ? 2 : 1;
}
