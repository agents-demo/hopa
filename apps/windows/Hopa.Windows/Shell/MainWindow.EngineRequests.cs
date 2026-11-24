using System.Text.Json.Nodes;
using System.Windows;
using Hopa.Windows.Dialogs;
using Hopa.Windows.Gateway;

namespace Hopa.Windows.Shell;

public partial class MainWindow : Window
{
    /// <summary>Approval goes to automation, the paired phone, or this window; the router decides.</summary>
    private void OnApprovalRequested(JsonObject message)
    {
        var router = new ApprovalRouter(
            askUser: request => Dispatcher.Invoke(
                () => new ApprovalWindow(request) { Owner = this }.ShowDialog() == true),
            phone: () => gateway,
            reply: (id, allow, source) => client?.SendApprovalResult(id, allow, source),
            log: Log,
            autoApproval: autoApproval);
        _ = router.HandleAsync(message);
    }

    private void OnDeviceRequested(JsonObject message)
    {
        var id = message["id"]?.GetValue<string>() ?? "";
        var op = message["op"]?.GetValue<string>() ?? "";
        if (client == null)
        {
            return;
        }

        try
        {
            if (op == "observe")
            {
                var (observation, nodes) = device.Observe();
                Log($"device: observed {nodes} nodes in '{observation["app"]}'");
                client.SendDeviceResult(id, true, observation: observation);
                return;
            }

            if (op == "foreground")
            {
                var app = device.ForegroundApp();
                client.SendDeviceResult(id, true, app: app);
                return;
            }

            if (op == "screenshot")
            {
                var png = device.CaptureWindow();
                if (png == null)
                {
                    Log("device: no frame (protected or not capturable)");
                    client.SendDeviceResult(id, true);
                    return;
                }

                client.SendDeviceResult(id, true, image: Convert.ToBase64String(png));
                return;
            }

            if (op == "apps")
            {
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

                Log($"device: {entries.Count} apps");
                client.SendDeviceResult(id, true, apps: array);
                return;
            }

            if (op == "openLink")
            {
                var opened = device.OpenLink(message["url"]?.GetValue<string>() ?? "");
                Log($"device: {opened}");
                client.SendDeviceResult(id, true, text: opened);
                return;
            }

            var info = device.Act(op, message);
            Log($"device: {info}");
            client.SendDeviceResult(id, true, text: info);
        }
        catch (Exception error)
        {
            Log($"device error: {error.Message}");
            client.SendDeviceResult(id, false, error.Message);
        }
    }
}
