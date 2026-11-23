namespace Api.Auth;

public static class RoleUtils
{
    public const int Admin = 1;
    public const int Registrar = 2;
    public const int Teacher = 3;
    public const int ProgramHead = 4;
    public const int Student = 5;
    public const int CollegeHead = 6;

    /// <summary>
    /// The Accounting Office. Signs in to the Registrar app but sees only its own screens:
    /// look up a student, and raise or lift an unpaid-balance hold. It deliberately cannot
    /// read grades -- the office that can withhold them has no reason to see them.
    /// </summary>
    public const int Accounting = 7;

    public static bool IsValidRole(int role)
    {
        return role is >= Admin and <= Accounting;
    }

    public static string GetRoleName(int role)
    {
        return role switch
        {
            Admin => "Admin",
            Registrar => "Registrar",
            Teacher => "Teacher",
            ProgramHead => "Program Head",
            Student => "Student",
            CollegeHead => "College Head",
            Accounting => "Accounting",
            _ => "Unknown"
        };
    }
}
