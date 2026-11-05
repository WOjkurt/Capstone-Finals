namespace Api.DTOs.Reports;

/// <summary>Students per program and year level in a term.</summary>
public class EnrollmentSummaryRowDto
{
    public string ProgramCode { get; set; } = string.Empty;
    public int? YearLevel { get; set; }
    /// <summary>Students with at least one Enrolled subject.</summary>
    public int EnrolledStudents { get; set; }
    /// <summary>Students whose load is still only Pending.</summary>
    public int PendingOnlyStudents { get; set; }
}

public class ClassSizeRowDto
{
    public Guid ClassId { get; set; }
    public string ClassName { get; set; } = string.Empty;
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public string ProgramCode { get; set; } = string.Empty;
    public string? TeacherName { get; set; }
    public int Enrolled { get; set; }
    public int Pending { get; set; }
}

public class FailedStudentRowDto
{
    public Guid UserId { get; set; }
    public string StudentName { get; set; } = string.Empty;
    public string? Lrn { get; set; }
    public string? ProgramCode { get; set; }
    public int? YearLevel { get; set; }
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public string ClassName { get; set; } = string.Empty;
    public decimal? FinalGrade { get; set; }
    public string? TeacherName { get; set; }
}

public class TeacherLoadRowDto
{
    /// <summary>Null for the "Unassigned" row.</summary>
    public Guid? TeacherUserId { get; set; }
    public string TeacherName { get; set; } = string.Empty;
    public int Classes { get; set; }
    public decimal Units { get; set; }
    public int Students { get; set; }
    public List<string> SubjectCodes { get; set; } = new();
}

/// <summary>A transferee (or any student with credits from another school).</summary>
public class TransfereeRowDto
{
    public Guid UserId { get; set; }
    public string StudentName { get; set; } = string.Empty;
    public string? Lrn { get; set; }
    public string? ProgramCode { get; set; }
    public int? YearLevel { get; set; }
    /// <summary>Schools on their credits; when there are none, the previous college from the enrollment form.</summary>
    public List<string> PreviousSchools { get; set; } = new();
    public int CreditedSubjects { get; set; }
    public decimal CreditedUnits { get; set; }
    public List<string> CreditedCodes { get; set; } = new();
}

/// <summary>Enrolled students of one program in a term, by year level (1st to 4th) and sex.</summary>
public class EnrollmentStatisticsRowDto
{
    public string ProgramCode { get; set; } = string.Empty;
    public string ProgramName { get; set; } = string.Empty;
    /// <summary>Index 0 is 1st year ... index 3 is 4th year; 5th year and up are counted as 4th.</summary>
    public int[] Male { get; set; } = new int[4];
    public int[] Female { get; set; } = new int[4];
    /// <summary>Enrolled students with no sex on record (counted in no column).</summary>
    public int SexNotRecorded { get; set; }
    /// <summary>Enrolled students with no year level (counted in no column).</summary>
    public int YearNotRecorded { get; set; }
}

/// <summary>One printable class list: the class details and its Enrolled students.</summary>
public class ClassListDto
{
    public Guid ClassId { get; set; }
    public string ClassName { get; set; } = string.Empty;
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectTitle { get; set; } = string.Empty;
    public decimal Units { get; set; }
    public string TermLabel { get; set; } = string.Empty;
    public string? TeacherName { get; set; }
    /// <summary>e.g. "M/W/F 8:00 AM - 9:30 AM · R101".</summary>
    public List<string> Schedules { get; set; } = new();
    public List<ClassListStudentDto> Students { get; set; } = new();
}

public class ClassListStudentDto
{
    public Guid UserId { get; set; }
    /// <summary>"LASTNAME, Firstname".</summary>
    public string Name { get; set; } = string.Empty;
    public string? Lrn { get; set; }
    public string? ProgramCode { get; set; }
    public int? YearLevel { get; set; }
    /// <summary>"M", "F", or null when not on record.</summary>
    public string? Sex { get; set; }
}

public class MissingSexRowDto
{
    public Guid UserId { get; set; }
    public string StudentName { get; set; } = string.Empty;
    public string? Lrn { get; set; }
    public string? ProgramCode { get; set; }
    public int? YearLevel { get; set; }
}
