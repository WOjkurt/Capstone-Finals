namespace Api.DTOs.Class;

public class CreateClassScheduleDto
{
    public Guid ClassID { get; set; }
    public required string DaysOfWeek { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
    public required string Room { get; set; }
}
