using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Gateway;

/// <summary>Reads the frame type and the fields once, so the socket loop does not parse JSON by hand.</summary>
public static class GatewayFrames
{
    public static GatewayFrame Parse(JsonObject frame)
    {
        var type = frame["type"]?.GetValue<string>() ?? "";
        var kind = type switch
        {
            "device.hello.ack" => GatewayFrameKind.HelloAck,
            "presence" => GatewayFrameKind.Presence,
            "ping" => GatewayFrameKind.Ping,
            "task.ack" => GatewayFrameKind.TaskAck,
            "task.result" => GatewayFrameKind.TaskResult,
            "task.needs_approval" => GatewayFrameKind.NeedsApproval,
            "task.create" => GatewayFrameKind.TaskCreate,
            "error" => GatewayFrameKind.Error,
            "pong" => GatewayFrameKind.Pong,
            _ => GatewayFrameKind.Unknown,
        };
        var body = frame["body"] as JsonObject;
        return new GatewayFrame(
            kind,
            frame,
            DeviceId: Text(frame, "to"),
            Peers: Peers(body),
            PresenceDevice: body is null ? null : Text(body, "device"),
            PresenceOnline: body?["online"]?.GetValue<bool>() ?? false,
            TaskId: body is null ? null : Text(body, "task"),
            From: Text(frame, "from"),
            To: Text(frame, "to"),
            Error: body is null ? null : Text(body, "message"));
    }

    private static IReadOnlyList<string>? Peers(JsonObject? body)
    {
        if (body?["peers"] is not JsonArray roster)
        {
            return null;
        }

        var peers = new List<string>();
        foreach (var item in roster)
        {
            if (item?.GetValue<string>() is { Length: > 0 } id)
            {
                peers.Add(id);
            }
        }

        return peers;
    }

    private static string? Text(JsonObject obj, string key) =>
        obj[key]?.GetValue<string>() is { Length: > 0 } value ? value : null;
}
