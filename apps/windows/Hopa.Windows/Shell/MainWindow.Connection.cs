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
using Hopa.Windows.Host;

namespace Hopa.Windows.Shell;

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
            var started = new EngineHostClient();
            started.LogReceived += line => Log($"sidecar: {line}");
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
            client = started;
            chatController = new ChatController(started, Chat.Model, Sidebar.Model);
            chatController.MessagesChanged += Chat.ScrollToEnd;

            gateway = CreateGateway();

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

    private GatewayClient CreateGateway()
    {
        var created = new GatewayClient();
        created.StateChanged += () => Dispatcher.BeginInvoke(() =>
        {
            client?.SendGatewayState(created.Paired, created.HasPhone);
            Log($"gateway: {created.Status}; phone={(created.HasPhone ? "online" : "offline")}");
        });
        created.TaskReceived += message => Dispatcher.BeginInvoke(() =>
            Log($"gateway task: {(message["body"] as JsonObject)?["goal"]?.GetValue<string>() ?? message["task"]?.GetValue<string>()}"));
        created.Start();
        return created;
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
        var dialog = new SettingsWindow { Owner = this };
        if (dialog.ShowDialog() == true)
        {
            await ApplySettingsAsync();
            if (gateway != null)
            {
                await gateway.StopAsync();
                await gateway.DisposeAsync();
            }
            gateway = CreateGateway();
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
