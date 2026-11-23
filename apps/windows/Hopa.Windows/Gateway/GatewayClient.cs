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
public sealed class GatewayClient : IAsyncDisposable
{
    private const int MaxFrameBytes = 65_536;

    private readonly SemaphoreSlim sendGate = new(1, 1);
    private readonly object pendingGate = new();
    private readonly HashSet<string> peers = new(StringComparer.Ordinal);
    private ClientWebSocket? socket;
    private CancellationTokenSource? cts;
    private Task? loop;
    private PendingOperation? waiting;

    public event Action? StateChanged;

    /// <summary>A task the other device started; the host may show or run it.</summary>
    public event Action<JsonObject>? TaskReceived;

    /// <summary>A phone or PC asks this device to approve a step.</summary>
    public event Action<JsonObject>? ApprovalReceived;

    public string DeviceId { get; private set; } = "";
    public string PhoneDeviceId { get; private set; } = "";
    public string Status { get; private set; } = "not paired";
    public bool IsLive { get; private set; }
    public bool Paired => GatewayCredentials.Load() != null;
    public bool HasPhone => IsLive && PhoneDeviceId.Length > 0;

    public void Start()
    {
        if (loop != null)
        {
            return;
        }

        cts = new CancellationTokenSource();
        loop = Task.Run(() => RunAsync(cts.Token));
    }

    public async Task StopAsync()
    {
        cts?.Cancel();
        try
        {
            if (loop != null)
            {
                await loop;
            }
        }
        catch (OperationCanceledException)
        {
            // Expected on shutdown.
        }
        loop = null;
        cts = null;
    }





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

    private async Task RunAsync(CancellationToken cancellationToken)
    {
        var backoffMs = 1_000;
        while (!cancellationToken.IsCancellationRequested)
        {
            var credentials = GatewayCredentials.Load();
            if (credentials == null)
            {
                SetState("not paired", live: false);
                return;
            }

            DeviceId = credentials.DeviceId;
            var authClose = false;
            try
            {
                using var ws = new ClientWebSocket();
                ws.Options.SetRequestHeader("Authorization", "Bearer " + credentials.AccessToken);
                await ws.ConnectAsync(new Uri(credentials.GatewayUrl), cancellationToken);
                socket = ws;
                await SendOnSocketAsync(ws, new JsonObject
                {
                    ["v"] = 1,
                    ["id"] = Guid.NewGuid().ToString(),
                    ["type"] = "device.hello",
                    ["ts"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    ["body"] = new JsonObject
                    {
                        ["platform"] = "windows",
                        ["name"] = Environment.MachineName,
                        ["appVersion"] = "0.1.0",
                    },
                }, cancellationToken);
                authClose = await ReceiveLoopAsync(ws, cancellationToken);
                backoffMs = 1_000;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception error)
            {
                SetState("offline: " + error.Message, live: false);
            }
            finally
            {
                socket = null;
                SetLive(false);
                FailPending("the gateway link closed");
            }

            if (authClose)
            {
                var refreshed = await GatewayPairing.RefreshAsync(credentials, cancellationToken);
                if (refreshed == null)
                {
                    SetState("pair again: the access token expired", live: false);
                    return;
                }
            }

            try
            {
                await Task.Delay(backoffMs, cancellationToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            backoffMs = Math.Min(backoffMs * 2, 30_000);
        }
    }

    private async Task<bool> ReceiveLoopAsync(ClientWebSocket ws, CancellationToken cancellationToken)
    {
        var buffer = new byte[MaxFrameBytes];
        while (ws.State == WebSocketState.Open && !cancellationToken.IsCancellationRequested)
        {
            using var message = new MemoryStream();
            WebSocketReceiveResult result;
            do
            {
                result = await ws.ReceiveAsync(new ArraySegment<byte>(buffer), cancellationToken);
                if (result.MessageType == WebSocketMessageType.Close)
                {
                    return ws.CloseStatus == WebSocketCloseStatus.PolicyViolation ||
                        (ws.CloseStatusDescription?.Contains("E_AUTH", StringComparison.OrdinalIgnoreCase) ?? false);
                }
                message.Write(buffer, 0, result.Count);
            } while (!result.EndOfMessage);

            JsonObject? frame;
            try
            {
                frame = JsonNode.Parse(Encoding.UTF8.GetString(message.ToArray())) as JsonObject;
            }
            catch (Exception)
            {
                continue;
            }
            if (frame != null)
            {
                await HandleFrameAsync(ws, frame, cancellationToken);
            }
        }
        return false;
    }

    private async Task HandleFrameAsync(ClientWebSocket ws, JsonObject frame, CancellationToken cancellationToken)
    {
        var type = frame["type"]?.GetValue<string>() ?? "";
        switch (type)
        {
            case "device.hello.ack":
                DeviceId = frame["to"]?.GetValue<string>() ?? DeviceId;
                peers.Clear();
                if (Body(frame)?["peers"] is JsonArray roster)
                {
                    foreach (var item in roster)
                    {
                        if (item?.GetValue<string>() is { Length: > 0 } id)
                        {
                            peers.Add(id);
                        }
                    }
                }
                UpdatePhone();
                SetState("live", live: true);
                break;

            case "presence":
                if (Body(frame)?["device"]?.GetValue<string>() is { Length: > 0 } device)
                {
                    var online = Body(frame)?["online"]?.GetValue<bool>() ?? false;
                    if (online)
                    {
                        peers.Add(device);
                    }
                    else
                    {
                        peers.Remove(device);
                    }
                    UpdatePhone();
                    StateChanged?.Invoke();
                }
                break;

            case "ping":
                await SendOnSocketAsync(ws, new JsonObject
                {
                    ["v"] = 1,
                    ["id"] = Guid.NewGuid().ToString(),
                    ["type"] = "pong",
                    ["ts"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    ["to"] = frame["from"]?.GetValue<string>(),
                }, cancellationToken);
                break;

            case "task.ack":
                if (Body(frame)?["task"]?.GetValue<string>() is { Length: > 0 } taskId)
                {
                    lock (pendingGate)
                    {
                        if (waiting != null)
                        {
                            waiting.TaskId = taskId;
                            waiting.Ack.TrySetResult(taskId);
                        }
                    }
                }
                break;

            case "task.result":
                // A decision is only accepted from the phone peer the server
                // authenticated; a result from anywhere else is not an answer.
                var from = frame["from"]?.GetValue<string>() ?? "";
                if (from.Length == 0 || from == PhoneDeviceId)
                {
                    lock (pendingGate)
                    {
                        if (waiting != null &&
                            (waiting.TaskId == null || waiting.TaskId == frame["task"]?.GetValue<string>()))
                        {
                            waiting.TaskId ??= frame["task"]?.GetValue<string>();
                            waiting.Ack.TrySetResult(waiting.TaskId ?? "");
                            waiting.Result.TrySetResult(frame);
                        }
                    }
                }
                if (Body(frame)?["approval"] != null)
                {
                    // The host reads the authenticated `from` to name the device.
                    ApprovalReceived?.Invoke(frame);
                }
                break;

            case "task.needs_approval":
                ApprovalReceived?.Invoke(frame);
                break;

            case "task.create":
                TaskReceived?.Invoke(frame);
                break;

            case "error":
                lock (pendingGate)
                {
                    if (waiting != null)
                    {
                        var message = Body(frame)?["message"]?.GetValue<string>() ?? "gateway error";
                        waiting.Ack.TrySetException(new InvalidOperationException(message));
                        waiting.Result.TrySetException(new InvalidOperationException(message));
                    }
                }
                break;

            case "pong":
                break;
        }
    }

    private static JsonObject? Body(JsonObject frame) => frame["body"] as JsonObject;

    private void FailPending(string message)
    {
        lock (pendingGate)
        {
            if (waiting == null)
            {
                return;
            }

            var error = new InvalidOperationException(message);
            waiting.Ack.TrySetException(error);
            waiting.Result.TrySetException(error);
            waiting = null;
        }
    }

    private void UpdatePhone()
    {
        PhoneDeviceId = peers.FirstOrDefault(id => !id.Equals(DeviceId, StringComparison.Ordinal)) ?? "";
        StateChanged?.Invoke();
    }

    private void SetState(string status, bool live)
    {
        Status = status;
        SetLive(live);
    }

    private void SetLive(bool live)
    {
        IsLive = live;
        StateChanged?.Invoke();
    }

    private async Task SendAsync(JsonObject frame)
    {
        var ws = socket ?? throw new InvalidOperationException("the gateway is not connected");
        await SendOnSocketAsync(ws, frame, CancellationToken.None);
    }

    private async Task SendOnSocketAsync(
        ClientWebSocket ws,
        JsonObject frame,
        CancellationToken cancellationToken)
    {
        var bytes = Encoding.UTF8.GetBytes(frame.ToJsonString());
        await sendGate.WaitAsync(cancellationToken);
        try
        {
            await ws.SendAsync(
                new ArraySegment<byte>(bytes),
                WebSocketMessageType.Text,
                true,
                cancellationToken);
        }
        finally
        {
            sendGate.Release();
        }
    }




    public async ValueTask DisposeAsync()
    {
        await StopAsync();
        socket?.Dispose();
        sendGate.Dispose();
    }

    private sealed class PendingOperation
    {
        public TaskCompletionSource<string> Ack { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public TaskCompletionSource<JsonObject> Result { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public string? TaskId { get; set; }
    }
}
