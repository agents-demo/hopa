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
        if (client == null)
        {
            return;
        }

        var items = await client.ListConversationsAsync(Sidebar.Model.IncludeArchived);
        var rows = items.Select(ConversationRow.From).ToList();
        if (rows.Count == 0)
        {
            var created = await client.CreateConversationAsync();
            if (created != null)
            {
                rows.Add(ConversationRow.From(created));
            }
        }

        Sidebar.Model.ReplaceAll(rows);
        if (Sidebar.Model.All.Count > 0)
        {
            await SelectAsync(Sidebar.Model.All[0].Id);
        }
    }

    private async Task SelectAsync(string id)
    {
        if (client == null || currentId == id)
        {
            return;
        }

        if (currentId != null)
        {
            Chat.Model.Drafts[currentId] = Chat.Model.ComposerText;
        }

        var open = await client.OpenConversationAsync(id);
        currentId = id;
        var draft = Chat.Model.Drafts.TryGetValue(id, out var saved) ? saved : "";
        Chat.Model.ShowConversation(open?["messages"] as JsonArray, draft);
        TitleText.Text = open?["title"]?.GetValue<string>() ?? "New chat";
        Sidebar.Select(conversations.FirstOrDefault(item => item.Id == id)
            ?? allConversations.FirstOrDefault(item => item.Id == id));
        Chat.ScrollToEnd();
        StatusText.Text = "";
    }

    private async Task SendAsync(string goal)
    {
        if (client == null || running)
        {
            return;
        }

        var attachment = pendingAttachment;
        pendingAttachment = null;
        Chat.Model.ClearAttachment();
        var body = goal.Length > 0
            ? goal
            : attachment != null ? Describe(attachment) : "";

        var previousQuestion = Chat.Model.LastQuestion;
        var clock = System.Diagnostics.Stopwatch.StartNew();
        running = true;
        Chat.Model.SetRunning(true);
        if (tray != null)
        {
            tray.Tooltip = "HOPA (working)";
            tray.StopEnabled = true;
        }

        StatusText.Text = "Working...";
        Chat.Model.ClearError();
        Chat.Model.AddUser(body);
        Chat.ScrollToEnd();
        try
        {
            var (answer, conversationId, title, steps, chainOk) =
                await client.StartTurnAsync(body, currentId, attachment);
            currentId = conversationId;
            MarkSelected(conversationId);
            Chat.Model.AddAnswer(answer, steps, chainOk);
            Log($"HOPA: {answer}");
            if (!IsActive)
            {
                var preview = answer.Length > 140 ? answer[..140] + "..." : answer;
                tray?.ShowBalloon("HOPA", preview);
            }
            foreach (var line in RunStepRow.Lines(steps))
            {
                Log($"step {line}");
            }

            if (steps is { Count: > 0 })
            {
                Log($"chain: {(chainOk ? "ok" : "failed")}");
            }

            TitleText.Text = title;
            clock.Stop();
            Rail.Model.ShowTurn(steps, chainOk, clock.Elapsed, previousQuestion);

            Chat.Model.LastQuestion = body;
            UpsertConversation(conversationId, title);
            Chat.ScrollToEnd();
            StatusText.Text = "";
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
            Chat.Model.ShowError(error.Message);
            Log($"error: {error.Message}");
        }
        finally
        {
            running = false;
            Chat.Model.SetRunning(false);
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
        if (running)
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

        if (currentId != null)
        {
            Chat.Model.Drafts[currentId] = "";
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

    private void UpsertConversation(string id, string title) => Sidebar.Model.Upsert(id, title);

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
            if (running)
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
        if (client == null)
        {
            return;
        }

        var created = await client.CreateConversationAsync();
        if (created == null)
        {
            return;
        }

        var row = ConversationRow.From(created);
        Sidebar.Model.All.Insert(0, row);
        Sidebar.ClearSearch();
        Sidebar.Model.ApplyFilter();
        currentId = null;
        MarkSelected(row.Id);
        await SelectAsync(row.Id);
    }

}
