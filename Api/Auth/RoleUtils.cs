namespace Api.Auth;

public static class RoleUtils
{
    public const int Admin = 1;
    public const int Registrar = 2;
    public const int Teacher = 3;
    public const int ProgramHead = 4;
    public const int Student = 5;

    public static bool IsValidRole(int role)
    {
        return role is >= Admin and <= Student;
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
            _ => "Unknown"
        };
    }
}
