using Microsoft.EntityFrameworkCore;

namespace Api.Services;

/// <summary>
/// Stops one teacher from being booked into two classes at the same time in a term.
/// Used when assigning a teacher and when saving a schedule for a class that has one.
/// </summary>
internal static class TeacherScheduleConflicts
{
    public static async Task EnsureNoConflictAsync(
        AppDbContext context,
        Guid teacherUserId,
        Guid termId,
        Guid classId,
        IEnumerable<(string DaysOfWeek, TimeOnly StartTime, TimeOnly EndTime)> slots,
        Guid? excludeScheduleId = null)
    {
        var newSlots = slots
            .Select(s => (Days: ParseDays(s.DaysOfWeek), s.StartTime, s.EndTime))
            .Where(s => s.Days.Count > 0)
            .ToList();
        if (newSlots.Count == 0)
        {
            return;
        }

        var query = context.ClassSchedules
            .AsNoTracking()
            .Include(cs => cs.Class)
                .ThenInclude(c => c!.Subject)
            .Where(cs => cs.Class != null &&
                         cs.Class.TermID == termId &&
                         cs.Class.UserID == teacherUserId &&
                         cs.ClassID != classId);

        if (excludeScheduleId.HasValue)
        {
            query = query.Where(cs => cs.ScheduleID != excludeScheduleId.Value);
        }

        var teacherSchedules = await query.ToListAsync();

        foreach (var existing in teacherSchedules)
        {
            var existingDays = ParseDays(existing.DaysOfWeek);
            foreach (var slot in newSlots)
            {
                bool daysOverlap = slot.Days.Overlaps(existingDays);
                bool timeOverlap = slot.StartTime < existing.EndTime && slot.EndTime > existing.StartTime;
                if (!daysOverlap || !timeOverlap)
                {
                    continue;
                }

                var details = await context.UserDetails
                    .AsNoTracking()
                    .FirstOrDefaultAsync(ud => ud.UserID == teacherUserId);
                string teacherName = details != null
                    ? $"{details.Firstname} {details.Lastname}".Trim()
                    : "This teacher";
                string subjectCode = existing.Class?.Subject?.SubjectCode ?? "another subject";
                string className = existing.Class?.ClassName ?? "another class";

                throw new InvalidOperationException(
                    $"{teacherName} already teaches {subjectCode} ({className}) " +
                    $"{existing.DaysOfWeek} {existing.StartTime:HH:mm}-{existing.EndTime:HH:mm} this term.");
            }
        }
    }

    private static HashSet<string> ParseDays(string daysOfWeek)
    {
        return daysOfWeek
            .Split(new[] { '/', ',', ' ' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(d => d.ToUpperInvariant())
            .ToHashSet();
    }
}
