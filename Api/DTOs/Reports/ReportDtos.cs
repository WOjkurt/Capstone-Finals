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
