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

    private async Task RefreshAsync()
    {
        if (chatController == null)
        {
            return;
        }

        var id = await chatController.LoadAsync(
            Sidebar.Model.IncludeArchived,
            createIfEmpty: true);
        if (id != null)
        {
            await SelectAsync(id);
        }
    }

    private async Task SelectAsync(string id)
    {
        if (chatController == null)
        {
            return;
        }

        var title = await chatController.SelectAsync(id);
        if (title == null)
        {
            return;
        }

        TitleText.Text = title;
        Sidebar.Select(conversations.FirstOrDefault(item => item.Id == id)
            ?? allConversations.FirstOrDefault(item => item.Id == id));
        Chat.ScrollToEnd();
        StatusText.Text = "";
    }

    private async Task SendAsync(string goal)
    {
        if (chatController == null || chatController.Running)
        {
            return;
        }

        var attachment = pendingAttachment;
        pendingAttachment = null;
        Chat.Model.ClearAttachment();
        var body = goal.Length > 0
            ? goal
            : attachment != null ? Describe(attachment) : "";

        if (tray != null)
        {
            tray.Tooltip = "HOPA (working)";
            tray.StopEnabled = true;
        }

        StatusText.Text = "Working...";
        Chat.ScrollToEnd();
        try
        {
            var report = await chatController.SendAsync(body, attachment);
            if (report.Error != null)
            {
                StatusText.Text = report.Error;
                Log($"error: {report.Error}");
                return;
            }

            Log($"HOPA: {report.Answer}");
            if (!IsActive)
            {
                var preview = report.Answer.Length > 140 ? report.Answer[..140] + "..." : report.Answer;
                tray?.ShowBalloon("HOPA", preview);
            }
            foreach (var line in RunStepRow.Lines(report.Steps))
            {
                Log($"step {line}");
            }

            if (report.Steps is { Count: > 0 })
            {
                Log($"chain: {(report.ChainOk ? "ok" : "failed")}");
            }

            TitleText.Text = report.Title;
            Rail.Model.ShowTurn(report.Steps, report.ChainOk, report.Elapsed, report.Earlier);
            Chat.ScrollToEnd();
            StatusText.Text = "";
        }
        finally
        {
            if (tray != null)
            {
                tray.Tooltip = "HOPA";
                tray.StopEnabled = false;
            }

            WriteLog();
        }
    }

    private async Task SendFromComposerAsync()
    {
        if (chatController?.Running == true)
        {
            client?.CancelTurn();
            StatusText.Text = "Stopping...";
            return;
        }

        var goal = Chat.Model.ComposerText.Trim();
        if (goal.Length == 0 && pendingAttachment == null)
        {
            return;
        }

        if (chatController?.CurrentId is { } current)
        {
            Chat.Model.Drafts[current] = "";
        }

        Chat.Model.ComposerText = "";
        await SendAsync(goal);
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

    private void MarkSelected(string? id) => Sidebar.Model.MarkSelected(id);

    protected override void OnPreviewKeyDown(KeyEventArgs e)
    {
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0)
        {
            switch (e.Key)
            {
                case Key.N:
                    _ = NewChatAsync();
                    e.Handled = true;
                    break;
                case Key.F:
                case Key.K:
                    Sidebar.FocusSearch();
                    e.Handled = true;
                    break;
            }
        }

        if (e.Key == Key.Escape)
        {
            if (chatController?.Running == true)
            {
                client?.CancelTurn();
            }

            speech?.SpeakAsyncCancelAll();
            voice.StopPlayback();
        }

        base.OnPreviewKeyDown(e);
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

    private async Task NewChatAsync()
    {
        if (chatController == null)
        {
            return;
        }

        var row = await chatController.CreateAsync();
        if (row == null)
        {
            return;
        }

        Sidebar.ClearSearch();
        Sidebar.Model.ApplyFilter();
        MarkSelected(row.Id);
        await SelectAsync(row.Id);
    }

}
