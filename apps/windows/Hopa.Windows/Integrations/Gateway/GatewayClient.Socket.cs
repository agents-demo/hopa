using System.IO;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Gateway;

/// <summary>
/// P4: the Windows half of the backend gateway. Pairing is HTTP; the live task
/// and approval traffic is one WebSocket. The host owns the token (Credential
/// Manager) and the sidecar only ever learns whether a phone peer is reachable.
/// </summary>
public sealed partial class GatewayClient
{
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
        var parsed = GatewayFrames.Parse(frame);
        switch (parsed.Kind)
        {
            case GatewayFrameKind.HelloAck:
                DeviceId = parsed.DeviceId ?? DeviceId;
                peers.Clear();
                if (parsed.Peers != null)
                {
                    foreach (var id in parsed.Peers)
                    {
                        peers.Add(id);
                    }
                }
                UpdatePhone();
                SetState("live", live: true);
                break;

            case GatewayFrameKind.Presence:
                if (parsed.PresenceDevice is { Length: > 0 } device)
                {
                    if (parsed.PresenceOnline)
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

            case GatewayFrameKind.Ping:
                await SendOnSocketAsync(ws, new JsonObject
                {
                    ["v"] = 1,
                    ["id"] = Guid.NewGuid().ToString(),
                    ["type"] = "pong",
                    ["ts"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    ["to"] = parsed.From,
                }, cancellationToken);
                break;

            case GatewayFrameKind.TaskAck:
                if (parsed.TaskId is { Length: > 0 } taskId)
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

            case GatewayFrameKind.TaskResult:
                // A decision is only accepted from the phone peer the server
                // authenticated; a result from anywhere else is not an answer.
                var from = parsed.From ?? "";
                if (from.Length == 0 || from == PhoneDeviceId)
                {
                    lock (pendingGate)
                    {
                        if (waiting != null &&
                            (waiting.TaskId == null || waiting.TaskId == parsed.TaskId))
                        {
                            waiting.TaskId ??= parsed.TaskId;
                            waiting.Ack.TrySetResult(waiting.TaskId ?? "");
                            waiting.Result.TrySetResult(frame);
                        }
                    }
                }
                if (parsed.Body?["approval"] != null)
                {
                    // The host reads the authenticated `from` to name the device.
                    ApprovalReceived?.Invoke(frame);
                }
                break;

            case GatewayFrameKind.NeedsApproval:
                ApprovalReceived?.Invoke(frame);
                break;

            case GatewayFrameKind.TaskCreate:
                TaskReceived?.Invoke(frame);
                break;

            case GatewayFrameKind.Error:
                lock (pendingGate)
                {
                    if (waiting != null)
                    {
                        var message = parsed.Error ?? "gateway error";
                        waiting.Ack.TrySetException(new InvalidOperationException(message));
                        waiting.Result.TrySetException(new InvalidOperationException(message));
                    }
                }
                break;

            case GatewayFrameKind.Pong:
            default:
                break;
        }
    }

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
}
