namespace Api.Services.Mail;

/// <summary>
/// What the school says to an applicant, kept apart from the sending of it so the wording can be
/// read and tested without a mail server.
///
/// These go to a personal address, because an applicant has no school email until the Registrar
/// issues one -- that is the whole reason they need telling. Plain text on purpose: it renders
/// the same everywhere, cannot leak a tracking pixel, and reads fine on a cheap phone.
///
/// Nothing here promises a place. Approval of an application is not enrollment, and the messages
/// say what the next step is rather than implying there is none.
/// </summary>
public static class EnrollmentNotices
{
    private const string Signature =
        "\n\n—\nOffice of the Registrar\nDon Bosco Technical College, Cebu\n\n"
        + "This message was sent automatically. Please do not reply to it; contact the "
        + "Registrar's Office if you need help.";

    private static string Greeting(string? firstName) =>
        string.IsNullOrWhiteSpace(firstName) ? "Hello," : $"Hello {firstName.Trim()},";

    /// <summary>
    /// Sent when the Registrar accepts an application. The school email usually does not exist
    /// yet at this point, so the message says one is coming rather than inventing a next step the
    /// applicant cannot take.
    /// </summary>
    public static (string Subject, string Body) Accepted(string? firstName, string? schoolYear, string? schoolEmail)
    {
        var forYear = string.IsNullOrWhiteSpace(schoolYear) ? "" : $" for {schoolYear.Trim()}";

        var next = string.IsNullOrWhiteSpace(schoolEmail)
            ? "The Registrar's Office will issue your DBTC school email address. Watch this inbox: "
              + "we will send it to you here, and you will use it to sign in to the Student Portal."
            : "Your DBTC school email address is:\n\n"
              + $"    {schoolEmail.Trim()}\n\n"
              + "Go to the Student Portal, choose Sign Up, and create your password using that "
              + "address. Your records are waiting under it.";

        return ($"Your DBTC-Cebu application has been accepted",
            $"{Greeting(firstName)}\n\n"
            + $"Good news — your application to Don Bosco Technical College, Cebu{forYear} has been accepted.\n\n"
            + $"{next}\n\n"
            + "Keep in mind that accepting your application is not the same as being enrolled. "
            + "The Registrar's Office will tell you what else is needed to complete your enrollment."
            + Signature);
    }

    /// <summary>
    /// Sent when the Registrar issues the school email. This is the message with something in it
    /// the applicant can act on, which is why it exists separately from the one above.
    /// </summary>
    public static (string Subject, string Body) SchoolEmailReady(string? firstName, string schoolEmail)
    {
        return ("Your DBTC-Cebu school email address",
            $"{Greeting(firstName)}\n\n"
            + "Your DBTC school email address has been issued:\n\n"
            + $"    {schoolEmail.Trim()}\n\n"
            + "Go to the Student Portal, choose Sign Up, and create your password using that "
            + "address. Only this address can reach your records, so keep it somewhere safe.\n\n"
            + "If you have trouble signing in, use \"Forgot password?\" on the sign-in page, or "
            + "contact the Registrar's Office."
            + Signature);
    }
}
