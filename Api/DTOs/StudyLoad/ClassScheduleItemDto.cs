namespace Api.DTOs.StudyLoad;

public class ClassScheduleItemDto
{
    public Guid ScheduleId { get; set; }
    public Guid ClassId { get; set; }
    public required string DaysOfWeek { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
    public required string Room { get; set; }
}
