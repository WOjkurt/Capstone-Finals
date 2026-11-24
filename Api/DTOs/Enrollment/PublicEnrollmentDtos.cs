namespace Api.DTOs.Enrollment;

/// <summary>
/// What the public enrollment page is told before it shows the form. Nothing here is specific
/// to a person: it is the same answer for every visitor, which is why it can be served without
/// a sign-in.
/// </summary>
public class PublicEnrollmentStatusDto
{
    /// <summary>Whether a term is open for enrolling today. False means the form is not shown at all.</summary>
    public bool IsOpen { get; set; }

    public string? TermLabel { get; set; }

    /// <summary>Last day a form can be submitted, so the page can say how long is left.</summary>
    public DateOnly? ClosesOn { get; set; }

    /// <summary>The courses an applicant can pick. Empty when enrollment is closed.</summary>
    public List<PublicProgramDto> Programs { get; set; } = new();
}

public class PublicProgramDto
{
    public int ProgramId { get; set; }
    public string ProgramCode { get; set; } = string.Empty;
    public string ProgramName { get; set; } = string.Empty;
}

/// <summary>
/// What the applicant is shown after submitting. There is no confirmation email, so this is the
/// only proof they get: the reference is short enough to write down or read over the phone, and
/// the Registrar can find the submission from it.
/// </summary>
public class PublicEnrollmentReceiptDto
{
    public Guid ResponseId { get; set; }

    /// <summary>The first block of the response id, upper-cased. Unique enough to look one up by.</summary>
    public string Reference { get; set; } = string.Empty;

    public string TermLabel { get; set; } = string.Empty;
    public DateTime SubmittedAt { get; set; }
}
