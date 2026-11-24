using System.Text.Json.Nodes;
using System.Windows;
using Hopa.Windows.Ui.Dialogs;
using Hopa.Windows.Host;
using Hopa.Windows.Storage;

namespace Hopa.Windows.Ui.Shell;

public partial class MainWindow : Window
{
    private async Task ConnectAsync()
    {
        connecting ??= ConnectCoreAsync();
        await connecting;
    }

    private async Task ConnectCoreAsync()
    {
        try
        {
            var started = new EngineSession();
            started.Log += line => Log($"sidecar: {line}");
            started.DeviceRequested += OnDeviceRequested;
            started.ApprovalRequested += OnApprovalRequested;
            started.SessionUpdated += message =>
            {
                var token = message["token"]?.GetValue<string>() ?? "";
                var refresh = message["refresh"]?.GetValue<string>() ?? "";
                if (token.Length > 0)
                {
                    CredentialStore.Write("hopa.bridge.token", token);
                    CredentialStore.Write("hopa.bridge.refresh", refresh);
                    Log("bridge session rotated; the host stored the new pair");
                }
            };
            started.StepReceived += message =>
            {
                var index = message["index"]?.GetValue<int>() ?? 0;
                var action = message["action"]?.GetValue<string>() ?? "?";
                var tier = message["tier"]?.GetValue<string>() ?? "";
                var executed = message["executed"]?.GetValue<bool>() == true;
                Log($"step {index}: {action} tier={tier} executed={executed}");
            };
            started.GatewayStateChanged += gateway => Dispatcher.BeginInvoke(() =>
            {
                client?.SendGatewayState(gateway.Paired, gateway.HasPhone);
                Log($"gateway: {gateway.Status}; phone={(gateway.HasPhone ? "online" : "offline")}");
            });
            started.TaskReceived += message => Dispatcher.BeginInvoke(() =>
                Log($"gateway task: {(message["body"] as JsonObject)?["goal"]?.GetValue<string>() ?? message["task"]?.GetValue<string>()}"));

            session = started;
            client = started.Client;
            chatController = new ChatController(started.Client, Chat.Model, Sidebar.Model);
            chatController.MessagesChanged += Chat.ScrollToEnd;
            started.Start();

            StatusText.Text = "Ready";
            UpdateBridgeStatus();
            await RefreshAsync();
            await ApplySettingsAsync();
        }
        catch (Exception error)
        {
            Chat.Model.ShowError(error.Message);
            StatusText.Text = error.Message;
            Log($"error: {error.Message}");
        }
    }

    private void UpdateBridgeStatus()
    {
        var settings = new SettingsStore().Load();
        var live = settings.BridgeUrl.Length > 0;
        Rail.Model.ShowBridge(live);
        Sidebar.Model.BridgeMissing = !live;
        var useBridge = settings.UseBridge;
        Chat.Model.SetTarget(live, useBridge);
        SubtitleText.Text = live ? "HOPA · Running on this laptop" : "Running on this laptop";
    }

    private async Task OpenSettingsAsync()
    {
        var dialog = new SettingsWindow(client, device) { Owner = this };
        if (dialog.ShowDialog() == true)
        {
            ApplyProfile();
            await ApplySettingsAsync();
            if (session != null)
            {
                await session.RestartGatewayAsync();
            }

            StatusText.Text = "Settings saved";
        }
    }

    private async Task ApplySettingsAsync()
    {
        if (client == null)
        {
            return;
        }

        try
        {
            var settings = new SettingsStore().Load();
            await client.ConfigureAsync(
                settings,
                CredentialStore.Read("hopa.bridge.token"),
                CredentialStore.Read("hopa.model.key"));
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
            Log($"error: {error.Message}");
        }
    }
}
