namespace Api.Common;

/// <summary>Today's date at the school (Philippine time, UTC+8), whatever time zone the server runs in.</summary>
public static class SchoolClock
{
    private static readonly TimeSpan Offset = TimeSpan.FromHours(8);

    public static DateOnly Today(DateTime? utcNow = null) =>
        DateOnly.FromDateTime((utcNow ?? DateTime.UtcNow) + Offset);
}
