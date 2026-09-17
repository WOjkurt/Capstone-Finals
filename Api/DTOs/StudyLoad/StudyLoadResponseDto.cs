namespace Api.DTOs.StudyLoad;

public class StudyLoadResponseDto
{
    public Guid StudyLoadId { get; set; }
    public Guid ClassId { get; set; }
    public Guid? StudentUserId { get; set; }
    public string? StudentName { get; set; }
    public required string SubjectCode { get; set; }
    public required string SubjectTitle { get; set; }
    public decimal Units { get; set; }
    public required string ClassName { get; set; }
    public string? TeacherName { get; set; }
    public required string LoadStatus { get; set; }
    public required string TermLabel { get; set; }
    public List<ClassScheduleItemDto> Schedules { get; set; } = new();
}
