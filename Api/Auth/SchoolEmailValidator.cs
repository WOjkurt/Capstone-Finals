using System.Diagnostics.CodeAnalysis;
using Microsoft.Extensions.Configuration;

namespace Api.Auth;

/// <summary>
/// Centralized validator for DBTC school email addresses.
/// Reused across FirebaseAuthMiddleware and EnrollmentApplication endpoints.
/// </summary>
public static class SchoolEmailValidator
{
    public const string DefaultDomain = "dbtc-cebu.edu.ph";

    public static string GetAllowedDomain(IConfiguration? configuration)
    {
        return (configuration?["Auth:AllowedEmailDomain"] ?? DefaultDomain).TrimStart('@');
    }

    public static string GetEmailDomain(string? email)
    {
        if (string.IsNullOrWhiteSpace(email)) return string.Empty;
        int lastAtIndex = email.LastIndexOf('@');
        return lastAtIndex >= 0 ? email[(lastAtIndex + 1)..] : string.Empty;
    }

    /// <summary>
    /// Exact case-insensitive domain comparison.
    /// Rejects lookalikes (evil-dbtc-cebu.edu.ph, sub.dbtc-cebu.edu.ph, etc.).
    /// </summary>
    public static bool IsValidDomain(string? email, string configuredDomain)
    {
        if (string.IsNullOrWhiteSpace(email)) return false;
        string emailDomain = GetEmailDomain(email);
        return string.Equals(emailDomain, configuredDomain.TrimStart('@'), StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Validates the format and domain of a school email.
    /// Normalizes the email to trimmed lowercase invariant if valid.
    /// </summary>
    public static bool TryValidateSchoolEmail(
        string? email,
        string configuredDomain,
        [NotNullWhen(true)] out string? normalizedEmail,
        out string? errorMessage)
    {
        normalizedEmail = null;
        errorMessage = null;

        if (string.IsNullOrWhiteSpace(email))
        {
            errorMessage = "School email cannot be empty.";
            return false;
        }

        var trimmed = email.Trim();
        if (trimmed.Contains(' '))
        {
            errorMessage = "School email cannot contain spaces.";
            return false;
        }

        int firstAtIndex = trimmed.IndexOf('@');
        int lastAtIndex = trimmed.LastIndexOf('@');

        if (firstAtIndex <= 0 || firstAtIndex != lastAtIndex || firstAtIndex == trimmed.Length - 1)
        {
            errorMessage = "Invalid email format.";
            return false;
        }

        string localPart = trimmed[..firstAtIndex];
        string domainPart = trimmed[(firstAtIndex + 1)..];

        if (string.IsNullOrWhiteSpace(localPart) || string.IsNullOrWhiteSpace(domainPart))
        {
            errorMessage = "Invalid email format.";
            return false;
        }

        string cleanConfiguredDomain = configuredDomain.TrimStart('@');
        if (!string.Equals(domainPart, cleanConfiguredDomain, StringComparison.OrdinalIgnoreCase))
        {
            errorMessage = $"School email domain must be exactly @{cleanConfiguredDomain}.";
            return false;
        }

        normalizedEmail = trimmed.ToLowerInvariant();
        return true;
    }
}
