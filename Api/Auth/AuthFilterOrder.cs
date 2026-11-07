namespace Api.Auth;

/// <summary>
/// ASP.NET checks a request body at order -2000. These run first, so someone who is not allowed
/// gets 401 or 403 and never sees validation messages that describe the endpoint.
/// </summary>
public static class AuthFilterOrder
{
    public const int SignedIn = -4000;
    public const int RoleCheck = -3000;
}
