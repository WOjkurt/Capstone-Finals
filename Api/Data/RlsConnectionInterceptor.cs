using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Npgsql;

namespace Api.Data;

/// <summary>
/// Pushes the caller's identity into the Postgres session so row-level security policies
/// can see who is asking. Without this every connection looks like the application role
/// and the policies have nothing to match on.
///
/// The four settings are written on EVERY connection open, never skipped. Npgsql resets a
/// connection when it returns to the pool, but relying on that alone would mean a single
/// missed reset leaks one user's context into another user's request. Writing unconditionally
/// makes a stale value impossible: whatever the previous borrower left behind is overwritten
/// before the first query runs.
///
/// An unauthenticated request gets empty strings rather than no setting at all. Policies then
/// match nothing and the row is refused, so a request that somehow bypasses the auth middleware
/// fails closed instead of inheriting whatever ran last.
/// </summary>
public sealed class RlsConnectionInterceptor : DbConnectionInterceptor
{
    private readonly IHttpContextAccessor _accessor;

    public RlsConnectionInterceptor(IHttpContextAccessor accessor) => _accessor = accessor;

    /// <summary>
    /// Four values, because the auth middleware needs two of them before it knows the other two.
    /// Verifying a Firebase token gives a UID and an email; turning those into a Users row is
    /// itself a query, and that query is subject to RLS. The Users policy therefore also accepts
    /// a match on firebase_uid or email, which is what lets a user be looked up before they are
    /// known. See the bootstrap policy in the AddRowLevelSecurity migration.
    /// </summary>
    private (string UserId, string Role, string FirebaseUid, string Email) Current()
    {
        var items = _accessor.HttpContext?.Items;
        if (items is null) return ("", "0", "", "");

        var userId = items.TryGetValue("user_id", out var u) && u is Guid g ? g.ToString() : "";
        var role = items.TryGetValue("role", out var r) && r is int i ? i.ToString() : "0";
        var uid = items.TryGetValue("firebase_uid", out var f) ? f as string ?? "" : "";
        var email = items.TryGetValue("email", out var e) ? e as string ?? "" : "";
        return (userId, role, uid, email);
    }

    public override void ConnectionOpened(DbConnection connection, ConnectionEndEventData eventData)
    {
        Apply(connection);
        base.ConnectionOpened(connection, eventData);
    }

    public override async Task ConnectionOpenedAsync(
        DbConnection connection, ConnectionEndEventData eventData, CancellationToken cancellationToken = default)
    {
        await ApplyAsync(connection, cancellationToken);
        await base.ConnectionOpenedAsync(connection, eventData, cancellationToken);
    }

    private const string Sql = """
        SELECT set_config('app.user_id', @user_id, false),
               set_config('app.role', @role, false),
               set_config('app.firebase_uid', @firebase_uid, false),
               set_config('app.email', @email, false)
        """;

    private NpgsqlCommand Build(DbConnection connection)
    {
        var (userId, role, uid, email) = Current();
        var cmd = (NpgsqlCommand)connection.CreateCommand();
        cmd.CommandText = Sql;
        // Parameters, not interpolation: app.email in particular is attacker-supplied.
        cmd.Parameters.AddWithValue("user_id", userId);
        cmd.Parameters.AddWithValue("role", role);
        cmd.Parameters.AddWithValue("firebase_uid", uid);
        cmd.Parameters.AddWithValue("email", email);
        return cmd;
    }

    private void Apply(DbConnection connection)
    {
        using var cmd = Build(connection);
        cmd.ExecuteNonQuery();
    }

    private async Task ApplyAsync(DbConnection connection, CancellationToken ct)
    {
        await using var cmd = Build(connection);
        await cmd.ExecuteNonQueryAsync(ct);
    }
}
