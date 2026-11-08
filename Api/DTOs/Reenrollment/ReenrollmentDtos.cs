using System.ComponentModel.DataAnnotations;
using Api.DTOs.Enrollment;

namespace Api.DTOs.Reenrollment;

/// <summary>Where an old student stands for online enrollment, and their form filled in from last time.</summary>
public class ReenrollmentStatusDto
{
    /// <summary>One of <see cref="ReenrollmentStates"/>.</summary>
    public required string State { get; set; }

    /// <summary>Why the student cannot enroll yet, in words they can act on.</summary>
    public List<string> Reasons { get; set; } = new();

    public Guid? TermId { get; set; }
    public string? TermLabel { get; set; }
    public DateOnly? OpensOn { get; set; }
    public DateOnly? ClosesOn { get; set; }

    public string? ProgramCode { get; set; }
    public string? ProgramName { get; set; }
    public int? CurrentYearLevel { get; set; }

    /// <summary>The year levels the student may pick: their current one and the next.</summary>
    public List<int> YearLevelChoices { get; set; } = new();

    /// <summary>Form fields the student cannot change here (name, birth, sex, LRN, schooling before DBTC).</summary>
    public List<string> LockedFields { get; set; } = new();

    /// <summary>Filled only when State is Ready.</summary>
    public EnrollmentFormDto? Form { get; set; }
    public List<ContactDto> Contacts { get; set; } = new();

    /// <summary>The term the pre-filled values come from, e.g. "2026-2027 (1st Sem)".</summary>
    public string? FilledFromTerm { get; set; }

    /// <summary>Filled when State is Submitted.</summary>
    public DateTime? SubmittedAt { get; set; }
    public string? ApplicationStatus { get; set; }
}

public static class ReenrollmentStates
{
    /// <summary>No term is open for online enrollment today.</summary>
    public const string Closed = "Closed";
    /// <summary>The student has to see the Registrar (no form on file, no earlier term, already has a load...).</summary>
    public const string NotEligible = "NotEligible";
    /// <summary>Not cleared for the last term, or an open hold.</summary>
    public const string OnHold = "OnHold";
    public const string Ready = "Ready";
    public const string Submitted = "Submitted";
}

public class SubmitReenrollmentDto
{
    public Guid TermId { get; set; }

    [Range(1, 5)]
    public int YearLevel { get; set; }

    [Required]
    public required EnrollmentFormDto Form { get; set; }

    [MaxLength(3)]
    public List<ContactDto> Contacts { get; set; } = new();

    /// <summary>The student ticked "I checked my information and it is correct".</summary>
    public bool Confirmed { get; set; }
}
