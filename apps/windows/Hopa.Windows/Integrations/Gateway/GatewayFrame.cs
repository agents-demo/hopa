using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Gateway;

/// <summary>One frame the backend gateway can send.</summary>
public enum GatewayFrameKind
{
    HelloAck,
    Presence,
    Ping,
    TaskAck,
    TaskResult,
    NeedsApproval,
    TaskCreate,
    Error,
    Pong,
    Unknown,
}

/// <summary>A parsed gateway frame: the kind plus the fields the client reads.</summary>
public sealed record GatewayFrame(
    GatewayFrameKind Kind,
    JsonObject Raw,
    string? DeviceId = null,
    IReadOnlyList<string>? Peers = null,
    string? PresenceDevice = null,
    bool PresenceOnline = false,
    string? TaskId = null,
    string? From = null,
    string? To = null,
    string? Error = null)
{
    public JsonObject? Body => Raw["body"] as JsonObject;
}
