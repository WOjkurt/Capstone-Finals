using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace Api.Services.Mail;

/// <summary>
/// Mail over SMTP, configured for the school's Google Workspace account.
///
/// Workspace is used rather than a mail service because the school already has it -- it is what
/// issues the school emails -- so there is nothing to pay for, no DNS to arrange, and no third
/// party holding applicants' addresses. It also means the message arrives from a real
/// dbtc-cebu.edu.ph address, which matters: mail from a noreply@*.firebaseapp.com sender is the
/// kind Gmail files as spam.
///
/// The password is an App Password, not the account's own password, which is why the account
/// needs 2FA turned on. Workspace will refuse plain account passwords from SMTP.
///
/// Configure under "Mail". Anything missing leaves this unconfigured and nothing is sent:
///   "Mail": {
///     "Host": "smtp.gmail.com",
///     "Port": 587,
///     "Username": "noreply@dbtc-cebu.edu.ph",
///     "Password": "<16-character app password>",
///     "FromName": "DBTC-Cebu Registrar"
///   }
/// Set Password through an environment variable, never in appsettings.json.
/// </summary>
public class SmtpSchoolMailer : ISchoolMailer
{
    private readonly ILogger<SmtpSchoolMailer> _logger;
    private readonly string _host;
    private readonly int _port;
    private readonly string _username;
    private readonly string _password;
    private readonly string _fromAddress;
    private readonly string _fromName;

    /// <summary>Workspace accounts cap at roughly 2,000 messages a day; one per applicant is nowhere near it.</summary>
    public SmtpSchoolMailer(IConfiguration configuration, ILogger<SmtpSchoolMailer> logger)
    {
        _logger = logger;
        _host = configuration["Mail:Host"] ?? string.Empty;
        _port = configuration.GetValue("Mail:Port", 587);
        _username = configuration["Mail:Username"] ?? string.Empty;
        _password = configuration["Mail:Password"] ?? string.Empty;
        _fromAddress = configuration["Mail:FromAddress"] ?? _username;
        _fromName = configuration["Mail:FromName"] ?? "DBTC-Cebu";
    }

    public bool IsConfigured =>
        _host.Length > 0 && _username.Length > 0 && _password.Length > 0 && _fromAddress.Length > 0;

    public async Task<bool> SendAsync(string toAddress, string subject, string body,
        CancellationToken cancellationToken = default)
    {
        if (!IsConfigured)
        {
            _logger.LogWarning("No mail account is configured, so nothing was sent. Set Mail:Host, Mail:Username and Mail:Password.");
            return false;
        }

        if (string.IsNullOrWhiteSpace(toAddress))
        {
            return false;
        }

        try
        {
            // Inside the try: addresses recorded before the public form existed were never
            // checked, so a Google Forms response can hold "none" or two addresses in one field,
            // and MailboxAddress.Parse throws on both. This method promises never to throw.
            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(_fromName, _fromAddress));
            message.To.Add(MailboxAddress.Parse(toAddress.Trim()));
            message.Subject = subject;
            message.Body = new TextPart("plain") { Text = body };

            using var client = new SmtpClient();
            // MailKit waits two minutes by default. This runs inside the request that approves an
            // application, so an unreachable mail server would leave the Registrar staring at a
            // frozen button over something incidental to what they asked for. Give up quickly and
            // log it instead: the approval has already been saved either way.
            client.Timeout = (int)TimeSpan.FromSeconds(15).TotalMilliseconds;
            // STARTTLS on 587: Workspace rejects an unencrypted session outright.
            await client.ConnectAsync(_host, _port, SecureSocketOptions.StartTls, cancellationToken);
            await client.AuthenticateAsync(_username, _password, cancellationToken);
            await client.SendAsync(message, cancellationToken);
            await client.DisconnectAsync(true, cancellationToken);
            return true;
        }
        catch (Exception ex)
        {
            // The address is deliberately not logged: an applicant's personal email is theirs.
            _logger.LogError(ex, "Could not send a {Subject} notice over SMTP.", subject);
            return false;
        }
    }
}

/// <summary>
/// Stands in when no mail account is configured, which is every developer machine and every test.
/// It records what would have gone out and sends nothing, so a missing mail account shows up in
/// the log rather than as a crash -- and never as a real message to a real applicant.
/// </summary>
public class UnconfiguredSchoolMailer : ISchoolMailer
{
    private readonly ILogger<UnconfiguredSchoolMailer> _logger;

    public UnconfiguredSchoolMailer(ILogger<UnconfiguredSchoolMailer> logger) => _logger = logger;

    public bool IsConfigured => false;

    public Task<bool> SendAsync(string toAddress, string subject, string body,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Mail is not configured; a {Subject} notice was not sent.", subject);
        return Task.FromResult(false);
    }
}
