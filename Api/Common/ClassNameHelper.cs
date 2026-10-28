namespace Api.Common;

public static class ClassNameHelper
{
    /// <summary>
    /// Formats standard class section name: "{ProgramCode} {YearLevel}{SectionLetter}" (e.g. "BSIT 1A").
    /// Change this implementation if DBTC uses another format, e.g. "BSIT 1-A".
    /// </summary>
    public static string Format(string programCode, int yearLevel, string sectionLetter)
        => $"{programCode} {yearLevel}{sectionLetter}";
}
