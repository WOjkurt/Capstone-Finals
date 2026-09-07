namespace Api.Domain.Enrollment;

public static class EnrollmentApplicationStatus
{
    public const int Pending = 1;
    public const int Approved = 2;
    public const int Rejected = 3;
    public const int Active = 4;

    public static bool TryParse(string? input, out int status)
    {
        status = 0;
        if (string.IsNullOrWhiteSpace(input))
        {
            return false;
        }

        var trimmed = input.Trim();
        if (int.TryParse(trimmed, out int intVal) && intVal is >= Pending and <= Active)
        {
            status = intVal;
            return true;
        }

        switch (trimmed.ToLowerInvariant())
        {
            case "pending":
                status = Pending;
                return true;
            case "approved":
                status = Approved;
                return true;
            case "rejected":
                status = Rejected;
                return true;
            case "active":
                status = Active;
                return true;
            default:
                return false;
        }
    }

    public static string GetName(int status)
    {
        return status switch
        {
            Pending => "Pending",
            Approved => "Approved",
            Rejected => "Rejected",
            Active => "Active",
            _ => "Unknown"
        };
    }
}
