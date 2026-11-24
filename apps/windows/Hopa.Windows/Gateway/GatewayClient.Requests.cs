using System.IO;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json.Nodes;

namespace Hopa.Windows.Gateway;

/// <summary>
/// P4: the Windows half of the backend gateway. Pairing is HTTP; the live task
/// and approval traffic is one WebSocket. The host owns the token (Credential
/// Manager) and the sidecar only ever learns whether a phone peer is reachable.
/// </summary>
public sealed partial class GatewayClient
{
    /// <summary>
    /// Ask the phone to approve one step. Returns the phone's task.result body,
    /// or null on timeout/error; the caller must deny on null.
    /// </summary>
    public async Task<JsonObject?> RequestApprovalAsync(
        JsonObject approval,
        string phoneDeviceId,
        TimeSpan timeout)
    {
        if (!HasPhone || phoneDeviceId.Length == 0)
        {
            return null;
        }

        var pending = new PendingOperation();
        lock (pendingGate)
        {
            waiting = pending;
        }

        try
        {
            await SendAsync(new JsonObject
            {
                ["v"] = 1,
                ["id"] = Guid.NewGuid().ToString(),
                ["type"] = "task.needs_approval",
                ["ts"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                ["to"] = phoneDeviceId,
                ["body"] = new JsonObject
                {
                    ["goal"] = approval["title"]?.GetValue<string>() ?? "approve this action",
                    ["approval"] = approval.DeepClone(),
                },
            });
            _ = await pending.Ack.Task.WaitAsync(TimeSpan.FromSeconds(15));
            return await pending.Result.Task.WaitAsync(timeout);
        }
        catch (TimeoutException)
        {
            return null;
        }
        catch (Exception)
        {
            return null;
        }
        finally
        {
            lock (pendingGate)
            {
                if (ReferenceEquals(waiting, pending))
                {
                    waiting = null;
                }
            }
        }
    }

    /// <summary>Hand a goal to the phone; the existing task runner executes it.</summary>
    public async Task<string?> SendTaskAsync(string goal, string phoneDeviceId)
    {
        if (!HasPhone || phoneDeviceId.Length == 0 || goal.Trim().Length == 0)
        {
            return null;
        }

        var pending = new PendingOperation();
        lock (pendingGate)
        {
            waiting = pending;
        }

        try
        {
            await SendAsync(new JsonObject
            {
                ["v"] = 1,
                ["id"] = Guid.NewGuid().ToString(),
                ["type"] = "task.create",
                ["ts"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                ["to"] = phoneDeviceId,
                ["body"] = new JsonObject { ["goal"] = goal.Trim() },
            });
            return await pending.Ack.Task.WaitAsync(TimeSpan.FromSeconds(15));
        }
        catch (Exception)
        {
            return null;
        }
        finally
        {
            lock (pendingGate)
            {
                if (ReferenceEquals(waiting, pending))
                {
                    waiting = null;
                }
            }
        }
    }
}
