using FirebaseAdmin.Auth;

namespace Api.Auth;

/// <summary>
/// Thrown by <see cref="IFirebaseAuthVerifier"/> when token verification fails for any reason.
/// Wraps <see cref="FirebaseAuthException"/> so that callers (and tests) never need to reference
/// the Firebase SDK's internal constructor directly.
/// </summary>
public class TokenVerificationException : Exception
{
    /// <summary>
    /// The Firebase SDK error code, e.g. <see cref="AuthErrorCode.ExpiredIdToken"/>
    /// or <see cref="AuthErrorCode.RevokedIdToken"/>. Used for logging and for producing
    /// distinct client-facing error codes when needed.
    /// </summary>
    public AuthErrorCode AuthErrorCode { get; }

    public TokenVerificationException(AuthErrorCode authErrorCode, string message, Exception? innerException = null)
        : base(message, innerException)
    {
        AuthErrorCode = authErrorCode;
    }
}
