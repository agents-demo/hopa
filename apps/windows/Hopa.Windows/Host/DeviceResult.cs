using System.Text.Json.Nodes;

namespace Hopa.Windows.Host;

/// <summary>One answer to a device request, in the shape the engine expects.</summary>
public sealed record DeviceResult(
    string Id,
    bool Ok,
    string? Error = null,
    JsonObject? Observation = null,
    string? App = null,
    string? Text = null,
    string? Image = null,
    JsonArray? Apps = null);
