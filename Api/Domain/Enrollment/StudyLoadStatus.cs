namespace Api.Domain.Enrollment;

public static class StudyLoadStatus
{
    public const int Enrolled = 1;
    public const int Dropped = 2;
    public const int Withdrawn = 3;
    public const int Pending = 4;

    public static bool IsValid(int status)
    {
        return status is Enrolled or Dropped or Withdrawn or Pending;
    }

    public static string GetDisplayText(int status)
    {
        return status switch
        {
            Enrolled => "Enrolled",
            Dropped => "Dropped",
            Withdrawn => "Withdrawn",
            Pending => "Pending",
            _ => $"Status {status}"
        };
    }
}
