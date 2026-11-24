namespace Api.Services.Mail;

/// <summary>
/// Sending a message from the school. One address, one subject, one plain-text body: everything
/// the SIS needs to tell somebody, and nothing that invites a marketing template.
///
/// Sending never throws. An email that does not arrive must not undo the thing it was announcing
/// -- an approved application stays approved whether or not the applicant was told -- so the
/// result is a bool the caller can log, not an exception the caller has to catch.
/// </summary>
public interface ISchoolMailer
{
    /// <summary>False when no mail account is configured, so the caller can say "not sent" honestly.</summary>
    bool IsConfigured { get; }

    Task<bool> SendAsync(string toAddress, string subject, string body, CancellationToken cancellationToken = default);
}
