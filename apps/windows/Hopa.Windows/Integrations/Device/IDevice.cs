using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Device;

/// <summary>The device operations an engine request can ask for.</summary>
public interface IDevice
{
    (JsonObject Observation, int Nodes) Observe();

    string ForegroundApp();

    byte[]? CaptureWindow();

    List<DeviceApp> Apps();

    string OpenLink(string url);

    string Act(string op, JsonObject message);
}
