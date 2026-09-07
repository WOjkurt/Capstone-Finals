using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Enrollment;

public class ClassSchedule
{
    [Key]
    public Guid ScheduleID { get; set; }

    public Guid ClassID { get; set; }
    public Class? Class { get; set; }

    public required string DaysOfWeek { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
    public required string Room { get; set; }
}
