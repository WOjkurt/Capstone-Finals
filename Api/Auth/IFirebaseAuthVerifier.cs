using FirebaseAdmin.Auth;

namespace Api.Auth;

/// <summary>
/// Abstracts Firebase ID token verification so that:
///   1. <see cref="FirebaseAuthMiddleware"/> never touches <see cref="FirebaseAuth.DefaultInstance"/> directly.
///   2. Tests can inject a mock that throws <see cref="TokenVerificationException"/> with any
///      <see cref="AuthErrorCode"/> (e.g. <see cref="AuthErrorCode.ExpiredIdToken"/>) without needing
///      to construct the Firebase SDK's internal <see cref="FirebaseAuthException"/> type.
/// </summary>
public interface IFirebaseAuthVerifier
{
    /// <summary>
    /// Returns <see langword="true"/> when <see cref="FirebaseAuth.DefaultInstance"/> is non-null
    /// and the SDK has been fully initialized. When <see langword="false"/>, calling
    /// <see cref="VerifyIdTokenAsync"/> is unsafe and the middleware should return 503.
    /// </summary>
    bool IsInitialized { get; }

    /// <summary>
    /// Verifies the given Firebase ID token.
    /// </summary>
    /// <param name="token">The raw JWT string from the Authorization header.</param>
    /// <param name="checkRevoked">
    /// When <see langword="true"/>, also rejects tokens that have been explicitly revoked
    /// (requires a network round-trip to Firebase).
    /// </param>
    /// <returns>The decoded <see cref="FirebaseToken"/> on success.</returns>
    /// <exception cref="TokenVerificationException">
    /// Thrown for any Firebase token verification failure (expired, revoked, invalid signature, etc.).
    /// Inspect <see cref="TokenVerificationException.AuthErrorCode"/> for the specific reason.
    /// </exception>
    Task<FirebaseToken> VerifyIdTokenAsync(string token, bool checkRevoked);
}
