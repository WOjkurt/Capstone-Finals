using System.Collections.Concurrent;

namespace Api.Services;

/// <summary>
/// Writes blocked sign-ins and denied requests to the activity log so the Registrar can see them.
/// The same event is written once per half hour, with at most 100 entries an hour in all,
/// so someone repeating a request cannot fill the log.
/// </summary>
public class SecurityEventLog
{
    private static readonly TimeSpan RepeatWindow = TimeSpan.FromMinutes(30);
    private const int MaxPerHour = 100;

    private readonly IServiceScopeFactory _scopes;
    private readonly ConcurrentDictionary<string, DateTime> _lastWritten = new();
    private readonly object _hourLock = new();
    private DateTime _hourStart = DateTime.MinValue;
    private int _writtenThisHour;

    public SecurityEventLog(IServiceScopeFactory scopes)
    {
        _scopes = scopes;
    }

    public async Task RecordAsync(string key, Guid? actorId, string action, string summary)
    {
        if (!ShouldWrite(key, DateTime.UtcNow)) return;

        // Its own scope, so this never saves unfinished changes from the blocked request.
        await using var scope = _scopes.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<IActivityLogService>().LogAsync(actorId, action, summary);
    }

    private bool ShouldWrite(string key, DateTime now)
    {
        lock (_hourLock)
        {
            if (now - _hourStart >= TimeSpan.FromHours(1))
            {
                _hourStart = now;
                _writtenThisHour = 0;
                foreach (var old in _lastWritten.Where(e => now - e.Value >= RepeatWindow).ToList())
                {
                    _lastWritten.TryRemove(old.Key, out _);
                }
            }

            if (_lastWritten.TryGetValue(key, out var last) && now - last < RepeatWindow) return false;
            if (_writtenThisHour >= MaxPerHour) return false;

            _lastWritten[key] = now;
            _writtenThisHour++;
            return true;
        }
    }
}
