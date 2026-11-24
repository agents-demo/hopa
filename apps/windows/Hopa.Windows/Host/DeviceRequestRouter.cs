using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Device;

namespace Hopa.Windows.Host;

/// <summary>Maps an engine device request to the Windows device and one reply.</summary>
public sealed class DeviceRequestRouter
{
    private readonly IDevice device;
    private readonly Action<DeviceResult> reply;
    private readonly Action<string> log;

    public DeviceRequestRouter(IDevice device, Action<DeviceResult> reply, Action<string> log)
    {
        this.device = device;
        this.reply = reply;
        this.log = log;
    }

    public void Handle(JsonObject message)
    {
        var id = message["id"]?.GetValue<string>() ?? "";
        var op = message["op"]?.GetValue<string>() ?? "";

        try
        {
            switch (op)
            {
                case "observe":
                    var (observation, nodes) = device.Observe();
                    log($"device: observed {nodes} nodes in '{observation["app"]}'");
                    reply(new DeviceResult(id, true, Observation: observation));
                    return;

                case "foreground":
                    reply(new DeviceResult(id, true, App: device.ForegroundApp()));
                    return;

                case "screenshot":
                    var png = device.CaptureWindow();
                    if (png == null)
                    {
                        log("device: no frame (protected or not capturable)");
                        reply(new DeviceResult(id, true));
                        return;
                    }

                    reply(new DeviceResult(id, true, Image: Convert.ToBase64String(png)));
                    return;

                case "apps":
                    var entries = device.Apps();
                    var array = new JsonArray();
                    foreach (var entry in entries)
                    {
                        array.Add(new JsonObject
                        {
                            ["package"] = entry.Package,
                            ["label"] = entry.Label,
                        });
                    }

                    log($"device: {entries.Count} apps");
                    reply(new DeviceResult(id, true, Apps: array));
                    return;

                case "openLink":
                    var opened = device.OpenLink(message["url"]?.GetValue<string>() ?? "");
                    // The result may repeat the URL; the log records only that
                    // a link was opened, not where it goes.
                    log("device: opened a link");
                    reply(new DeviceResult(id, true, Text: opened));
                    return;

                default:
                    var info = device.Act(op, message);
                    log($"device: {info}");
                    reply(new DeviceResult(id, true, Text: info));
                    return;
            }
        }
        catch (Exception error)
        {
            log($"device error: {error.Message}");
            reply(new DeviceResult(id, false, Error: error.Message));
        }
    }
}
