namespace Api.DTOs.Class;

public class ClassDto
{
    public Guid ClassID { get; set; }

    public Guid SubjectID { get; set; }
    public string? SubjectCode { get; set; }
    public string? SubjectTitle { get; set; }

    public Guid? UserID { get; set; }
    public string? TeacherName { get; set; }

    public Guid TermID { get; set; }
    public string? TermSchoolYear { get; set; }
    public int? TermSemester { get; set; }

    public required string ClassName { get; set; }

    public DateTime CreatedAt { get; set; }
    public Guid? CreatedByUserID { get; set; }

    public int EnrolledCount { get; set; }

    public int? YearLevel { get; set; }

    public bool IsMinor { get; set; }

    public int? ProgramID { get; set; }

    public Guid? CurriculumID { get; set; }
    public string? CurriculumName { get; set; }

    /// <summary>True when the subject's program has more than one curriculum, so screens should say which one.</summary>
    public bool ShowCurriculum { get; set; }

    public List<ClassScheduleDto> Schedules { get; set; } = new();
}
