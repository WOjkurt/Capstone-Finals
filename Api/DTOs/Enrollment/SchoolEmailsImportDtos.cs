namespace Api.DTOs.Enrollment;

/// <summary>What importing the IT department's list of school emails would do (dry run) or did.</summary>
public class SchoolEmailsImportResultDto
{
    public bool DryRun { get; set; }
    /// <summary>Students who get their school email (including <see cref="Changed"/>).</summary>
    public int Emails { get; set; }
    /// <summary>Of those, students whose earlier email (set by hand) is replaced.</summary>
    public int Changed { get; set; }
    /// <summary>Students who already have exactly this email; nothing to do.</summary>
    public int AlreadySet { get; set; }
    /// <summary>Rows of people who are not students in the system (left out).</summary>
    public int NotInSystem { get; set; }
    public List<SchoolEmailsImportRowDto> Rows { get; set; } = new();
    public List<Api.DTOs.Records.RecordsImportProblemDto> Problems { get; set; } = new();
    public int TotalProblems { get; set; }

    /// <summary>For the activity log after a real import (not sent).</summary>
    [System.Text.Json.Serialization.JsonIgnore]
    public List<(Guid UserId, string OldEmail, string NewEmail)> Saved { get; } = new();
}

public class SchoolEmailsImportRowDto
{
    public string Sheet { get; set; } = string.Empty;
    public int Row { get; set; }
    public string StudentId { get; set; } = string.Empty;
    public string StudentName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    /// <summary>The email it replaces, when one was set by hand before.</summary>
    public string? OldEmail { get; set; }
    /// <summary>"Student ID" or "name".</summary>
    public string MatchedBy { get; set; } = string.Empty;
}
