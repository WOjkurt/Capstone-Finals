using FirebaseAdmin.Auth;

namespace Api.Auth;

/// <summary>
/// Production implementation of <see cref="IFirebaseAuthVerifier"/>.
/// Delegates to <see cref="FirebaseAuth.DefaultInstance"/> and translates
/// <see cref="FirebaseAuthException"/> → <see cref="TokenVerificationException"/> so that
/// callers never need to reference the Firebase SDK's internal exception constructor.
/// </summary>
public class FirebaseAuthVerifier : IFirebaseAuthVerifier
{
    /// <inheritdoc/>
    public bool IsInitialized => FirebaseAuth.DefaultInstance != null;

    /// <inheritdoc/>
    /// <exception cref="TokenVerificationException">
    /// Wraps any <see cref="FirebaseAuthException"/> thrown by the SDK (expired token,
    /// revoked token, invalid signature, etc.).
    /// </exception>
    public async Task<FirebaseToken> VerifyIdTokenAsync(string token, bool checkRevoked)
    {
        try
        {
            return await FirebaseAuth.DefaultInstance!.VerifyIdTokenAsync(token, checkRevoked);
        }
        catch (FirebaseAuthException ex)
        {
            // Re-throw as our own domain exception so the middleware (and tests) only
            // depend on Api.Auth types, not on Firebase SDK internals.
            throw new TokenVerificationException(
                ex.AuthErrorCode.GetValueOrDefault(), ex.Message, ex);
        }
        // All other exceptions (network failures, etc.) are intentionally not caught here;
        // the middleware's outer catch (Exception) handles them separately.
    }
}
