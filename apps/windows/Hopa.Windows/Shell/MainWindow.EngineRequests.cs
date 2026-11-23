using System.Collections.ObjectModel;
using System.IO;
using System.Net.Http;
using System.Speech.Synthesis;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using System.Windows.Shell;
using Hopa.Windows.Chat;
using Hopa.Windows.Checks;
using Hopa.Windows.Dialogs;
using Hopa.Windows.Device;
using Hopa.Windows.Engine;
using Hopa.Windows.Gateway;
using Hopa.Windows.Storage;
using Hopa.Windows.Voice;

namespace Hopa.Windows.Shell;

public partial class MainWindow : Window
{
    private void OnApprovalRequested(JsonObject message)
    {
        if (autoApproval != null)
        {
            var allowed = autoApproval == "allow";
            Log($"approval: auto-{(allowed ? "allow" : "deny")} {message["title"]?.GetValue<string>()}");
            client?.SendApprovalResult(message["id"]?.GetValue<string>() ?? "", allowed);
            return;
        }

        var phone = gateway?.PhoneDeviceId ?? "";
        if (gateway != null && gateway.IsLive && phone.Length > 0)
        {
            var requestId = message["id"]?.GetValue<string>() ?? "";
            _ = Task.Run(async () =>
            {
                var allow = false;
                var source = "pc";
                try
                {
                    var result = await gateway.RequestApprovalAsync(
                        BuildApproval(message),
                        phone,
                        TimeSpan.FromSeconds(100));
                    allow = ApprovalAllowed(result);
                    source = result == null ? "pc" : "phone";
                    if (result == null)
                    {
                        Log("approval: the phone did not answer; deny");
                    }
                }
                catch (Exception error)
                {
                    Log($"approval: the phone link failed ({error.Message}); deny");
                }
                finally
                {
                    client?.SendApprovalResult(requestId, allow, source);
                    _ = Dispatcher.BeginInvoke(() =>
                        Log($"approval: {(allow ? "allow" : "deny")} from {source}: {message["title"]?.GetValue<string>()}"));
                }
            });
            return;
        }

        Dispatcher.Invoke(() =>
        {
            var allow = false;
            var dialog = new ApprovalWindow(message) { Owner = this };
            if (dialog.ShowDialog() == true)
            {
                allow = true;
            }

            Log($"approval: {(allow ? "allow" : "deny")} {message["title"]?.GetValue<string>()}");
            client?.SendApprovalResult(message["id"]?.GetValue<string>() ?? "", allow);
        });
    }

    private static JsonObject BuildApproval(JsonObject message) => new()
    {
        ["title"] = message["title"]?.GetValue<string>() ?? "Allow this action?",
        ["body"] = message["body"]?.GetValue<string>() ?? "",
        ["amount"] = message["amount"]?.GetValue<string>() ?? "",
        ["merchant"] = message["merchant"]?.GetValue<string>() ?? "",
        ["consequence"] = message["consequence"]?.GetValue<string>() ?? "",
        ["isPayment"] = message["isPayment"]?.GetValue<bool>() ?? false,
        ["action"] = new JsonObject
        {
            ["schemaVersion"] = "1",
            ["kind"] = message["action"]?.GetValue<string>() ?? "ui.tap",
            ["timeoutMs"] = 3000,
        },
    };

    private static bool ApprovalAllowed(JsonObject? result) =>
        (result?["body"] as JsonObject)?["approval"] is JsonObject approval &&
        (approval["allow"]?.GetValue<bool>() ?? false);

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
