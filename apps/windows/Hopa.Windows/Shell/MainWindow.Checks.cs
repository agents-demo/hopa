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
    public async Task RunTurnAsync(string goal, string? outPath, string? shotPath, string? approval = null)
    {
        outputPath = outPath;
        autoApproval = approval;
        await ConnectAsync();
        await SendAsync(goal);
        WriteLog();
        if (shotPath != null)
        {
            await Task.Delay(400);
            SaveShot(shotPath);
        }

        Application.Current.Shutdown();
    }

    public async Task ListAsync(string? outPath)
    {
        outputPath = outPath;
        await ConnectAsync();
        foreach (var conversation in conversations)
        {
            Log($"{conversation.Id} | {conversation.Title} | {conversation.MessageCount}");
        }

        WriteLog();
        Application.Current.Shutdown();
    }

    public void SaveShot(string path) => WindowScreenshot.Save(this, path);

    /// <summary>A real screen grab of the window, frame and shadow included.</summary>
    public void FrameShot(string path)
    {
        Activate();
        Thread.Sleep(700);
        var png = device.CaptureWindow();
        if (png == null)
        {
            File.WriteAllText(path + ".error", "no frame");
        }
        else
        {
            File.WriteAllBytes(path, png);
        }

        Application.Current.Shutdown();
    }

    /// <summary>W6: a chat with real content, a long answer, an attachment and an error line.</summary>
    public void ShotChat(string directory)
    {
        Directory.CreateDirectory(directory);
        Chat.Model.ShowMock(
            new[]
            {
                new MessageBubble { Role = "user", Text = "Pay the internet bill, then email me the receipt." },
                new MessageBubble
                {
                    Role = "assistant",
                    Text = "Done. CityNet was paid 42.00 from the household account, the payment screen " +
                           "confirmed it, and the receipt went to your inbox. The bank app is still open " +
                           "on the payments screen if you want to check the reference number yourself.",
                },
                new MessageBubble { Role = "user", Text = "Thanks, and remind me on the 3rd." },
            },
            "The bridge is not running; the last step was not verified.",
            "bill-2026-11.pdf",
            "48 KB \u00B7 application/pdf");
        pendingAttachment = null;
        StatusText.Text = "";
        Rail.Model.ShowMock("Succeeded", "4 steps · 6.2 s", new[]
        {
            new RunStepRow { Number = "1", Verb = "Open app", Detail = "Calculator, brought to the front",
                Dot = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B)) },
            new RunStepRow { Number = "2", Verb = "Type", Detail = "42.00 into the amount field",
                Dot = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B)) },
            new RunStepRow { Number = "3", Verb = "Tap", Detail = "Confirm, payment, approved by the family",
                Dot = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B)) },
            new RunStepRow { Number = "4", Verb = "Verified", Detail = "receipt sent; the paid screen matched",
                Dot = new SolidColorBrush(Color.FromRgb(0x7B, 0x61, 0x3A)) },
        });
        WindowScreenshot.Save(this, Path.Combine(directory, "windows-w6-chat.png"));
        Application.Current.Shutdown();
    }

    /// <summary>W6: the controls Tab can reach, in visual-tree order, with their names.</summary>
    public void KeyboardCheck(string directory)
    {
        Directory.CreateDirectory(directory);
        var stops = new List<string>();
        CollectStops(this, stops);
        var lines = new List<string>
        {
            "tab order (visual tree): " + string.Join(" -> ", stops),
            $"focusable stops: {stops.Count}",
            "focus ring: #E8703A, 1.5 px, from the shared Button and ListBoxItem templates",
        };
        File.WriteAllLines(Path.Combine(directory, "keyboard-check.txt"), lines);
        Application.Current.Shutdown();
    }

    private static void CollectStops(DependencyObject root, List<string> stops)
    {
        if (root is System.Windows.FrameworkElement element && element.Focusable && element.IsVisible && element.IsEnabled)
        {
            var name = System.Windows.Automation.AutomationProperties.GetName(element);
            var fallback = element switch
            {
                System.Windows.Controls.TextBox box => $"text field '{box.Text}'",
                System.Windows.Controls.CheckBox check => $"check '{check.Content}'",
                System.Windows.Controls.Primitives.ButtonBase button => $"button '{button.Content}'",
                System.Windows.Controls.ListBox => "conversation list",
                _ => element.GetType().Name,
            };
            stops.Add(name.Length > 0 ? name : fallback);
        }

        var children = System.Windows.Media.VisualTreeHelper.GetChildrenCount(root);
        for (var index = 0; index < children; index++)
        {
            CollectStops(System.Windows.Media.VisualTreeHelper.GetChild(root, index), stops);
        }
    }

    /// <summary>W6: the windows that only appear mid-turn, rendered for the parity table.</summary>
    public void ShotComponents(string directory)
    {
        Directory.CreateDirectory(directory);

        var approval = new ApprovalWindow(new System.Text.Json.Nodes.JsonObject
        {
            ["title"] = "Pay the internet bill?",
            ["body"] = "The bank app is open on the payment screen.",
            ["amount"] = "42.00",
            ["merchant"] = "CityNet",
            ["consequence"] = "The money leaves the account and cannot be taken back.",
        })
        {
            Owner = this,
        };
        approval.Show();
        approval.UpdateLayout();
        Directory.CreateDirectory(directory);
        WindowScreenshot.Save(approval, Path.Combine(directory, "windows-w6-approval.png"));
        approval.Close();

        var steps = new RunDetailsWindow(new[]
        {
            "1 tap Payments (verified)",
            "2 tap Internet (verified)",
            "3 type 42.00 (verified)",
            "4 tap Confirm, payment, approved by the family",
        })
        {
            Owner = this,
        };
        steps.Show();
        steps.UpdateLayout();
        WindowScreenshot.Save(steps, Path.Combine(directory, "windows-w6-steps.png"));
        steps.Close();

        Application.Current.Shutdown();
    }

    /// <summary>
    /// W4 close-out: the desktop behaviours that need a window but not a sidecar.
    /// Writes a transcript and one screenshot; every line is a claim the reader
    /// can check in the UI.
    /// </summary>
    public void W4Check(string directory)
    {
        Directory.CreateDirectory(directory);
        var lines = new List<string>();
        try
        {
            W4CheckBody(directory, lines);
        }
        catch (Exception error)
        {
            lines.Add($"error: {error.GetType().Name}: {error.Message}");
        }

        File.WriteAllLines(Path.Combine(directory, "w4-check.txt"), lines);
        Application.Current.Shutdown();
    }

    private void W4CheckBody(string directory, List<string> lines)
    {
        lines.AddRange(new[]
        {
            $"tray icon created: {tray != null}",
            $"tray Stop disabled before a turn: {tray?.StopEnabled == false}",
            $"tray tooltip: '{tray?.Tooltip}'",
            $"high contrast active: {SystemParameters.HighContrast}",
            "shortcuts: Ctrl+N new chat; Ctrl+F or Ctrl+K search; Enter send; Shift+Enter newline; Esc stop",
            $"window bounds: {Left:0},{Top:0} {Width:0}x{Height:0}",
            $"window on a screen: {WindowPlacement.IsOnAnyScreen(new Rect(Left, Top, Width, Height))}",
            $"off-screen restore refused: {!WindowPlacement.IsOnAnyScreen(new Rect(-9000, -9000, Width, Height))}",
            $"automation names on controls: {CountNames(this)}",
            $"focusable controls: {CountFocusable(this)}",
            $"tab navigation: {KeyboardNavigation.GetTabNavigation(this)}",
        });

        if (tray != null)
        {
            lines.Add("toast: shown through the tray balloon");
            Dispatcher.BeginInvoke(new Action(() =>
                tray.ShowBalloon("HOPA", "W4 check: notification while the window is unfocused")));
        }
        else
        {
            lines.Add("toast: no tray icon");
        }

        var shot = Path.Combine(directory, "windows-w4.png");
        WindowScreenshot.Save(this, shot);
        lines.Add($"screenshot: {shot}");
    }

    private static int CountFocusable(DependencyObject root)
    {
        var count = root is System.Windows.FrameworkElement element && element.Focusable && element.IsVisible ? 1 : 0;
        var children = System.Windows.Media.VisualTreeHelper.GetChildrenCount(root);
        for (var index = 0; index < children; index++)
        {
            count += CountFocusable(System.Windows.Media.VisualTreeHelper.GetChild(root, index));
        }

        return count;
    }

    private static int CountNames(DependencyObject root)
    {
        var count = System.Windows.Automation.AutomationProperties.GetName(root).Length > 0 ? 1 : 0;
        var children = System.Windows.Media.VisualTreeHelper.GetChildrenCount(root);
        for (var index = 0; index < children; index++)
        {
            count += CountNames(System.Windows.Media.VisualTreeHelper.GetChild(root, index));
        }

        return count;
    }

    public async Task ShotSettingsAsync(string path)
    {
        await ConnectAsync();
        var dialog = new SettingsWindow { Owner = this };
        dialog.Show();
        await Task.Delay(600);
        WindowScreenshot.Save(dialog, path);
        dialog.Close();
        Application.Current.Shutdown();
    }

    public async Task DraftCheckAsync(string path)
    {
        await ConnectAsync();
        var lines = new List<string>();
        if (client == null || currentId == null)
        {
            lines.Add("draft round-trip: FAIL (not connected)");
            File.WriteAllLines(path, lines);
            Application.Current.Shutdown();
            return;
        }

        var firstId = currentId;
        var other = conversations.FirstOrDefault(item => item.Id != firstId);
        if (other == null)
        {
            var created = await client.CreateConversationAsync();
            var id = created?["id"]?.GetValue<string>();
            if (id != null)
            {
                conversations.Add(ConversationRow.From(created!));
                other = conversations.First(item => item.Id == id);
            }
        }

        if (other == null)
        {
            lines.Add("draft round-trip: FAIL (no second conversation)");
            File.WriteAllLines(path, lines);
            Application.Current.Shutdown();
            return;
        }

        Chat.Model.ComposerText = "draft one";
        await SelectAsync(other.Id);
        var cleared = Chat.Model.ComposerText;
        await SelectAsync(firstId);
        var restored = Chat.Model.ComposerText;
        lines.Add($"second conversation: {other.Id}");
        lines.Add($"composer after switch: '{cleared}' (expected '')");
        lines.Add($"draft restored: '{restored}' (expected 'draft one')");
        lines.Add($"draft round-trip: {(cleared.Length == 0 && restored == "draft one" ? "ok" : "FAIL")}");
        File.WriteAllLines(path, lines);
        Application.Current.Shutdown();
    }

    public async Task BridgeCheckAsync(string url, string token, string path)
    {
        var settings = new SettingsStore();
        var current = settings.Load();
        current.BridgeUrl = url;
        current.UseBridge = true;
        settings.Save(current);
        CredentialStore.Write("hopa.bridge.token", token);

        outputPath = path;
        autoApproval = "allow";
        await ConnectAsync();
        await SendAsync("open settings on the phone");
        WriteLog();
        Application.Current.Shutdown();
    }

    public async Task AttachCheckAsync(string file, string path)
    {
        outputPath = path;
        await ConnectAsync();
        var lines = new List<string>();
        if (client == null)
        {
            lines.Add("attach check: FAIL (not connected)");
        }
        else
        {
            try
            {
                var attachment = await client.AttachFileAsync(file);
                var name = attachment["name"]?.GetValue<string>() ?? "";
                var bytes = attachment["bytes"]?.GetValue<long>() ?? 0;
                var local = attachment["path"]?.GetValue<string>() ?? "";
                var created = await client.CreateConversationAsync();
                var id = created?["id"]?.GetValue<string>() ?? "";
                await client.StartTurnAsync($"attached {name}", id, attachment);
                var exported = await client.ExportConversationAsync(id);
                lines.Add($"attached: {name} ({bytes} bytes)");
                lines.Add($"in conversation: {exported.Contains(name)}");
                lines.Add($"copy exists: {File.Exists(local)}");
            }
            catch (Exception error)
            {
                lines.Add($"error: {error.Message}");
            }
        }

        File.WriteAllLines(path, lines);
        Application.Current.Shutdown();
    }

    public async Task CancelCheckAsync(string path)
    {
        outputPath = path;
        autoApproval = "allow";
        await ConnectAsync();
        var lines = new List<string>();
        if (client == null)
        {
            lines.Add("cancel check: FAIL (not connected)");
        }
        else
        {
            try
            {
                var turn = client.StartTurnAsync("slow turn please", currentId);
                await Task.Delay(1000);
                client.CancelTurn();
                var (answer, _, _, steps, _) = await turn;
                lines.Add($"answer: {answer}");
                lines.Add($"cancelled: {answer.Contains("Stopped", StringComparison.OrdinalIgnoreCase)}");
                lines.Add($"steps: {steps?.Count ?? 0}");
            }
            catch (Exception error)
            {
                lines.Add($"error: {error.Message}");
            }
        }

        File.WriteAllLines(path, lines);
        Application.Current.Shutdown();
    }

    public async Task HistoryCheckAsync(string path)
    {
        outputPath = path;
        await ConnectAsync();
        var lines = new List<string>();
        if (client == null)
        {
            lines.Add("history check: FAIL (not connected)");
            File.WriteAllLines(path, lines);
            Application.Current.Shutdown();
            return;
        }

        var created = await client.CreateConversationAsync();
        var id = created?["id"]?.GetValue<string>() ?? "";
        string renamed = "FAIL";
        var hits = new List<JsonObject>();
        var exported = "";
        var deleted = false;
        var remaining = -1;
        try
        {
            renamed = await client.RenameConversationAsync(id, "Groceries") is { } r
                ? r["title"]?.GetValue<string>() ?? "FAIL"
                : "FAIL";
            hits = await client.SearchConversationsAsync("Grocer");
            exported = await client.ExportConversationAsync(id);
            var pinned = (await client.PinConversationAsync(id, true))?["pinned"]?.GetValue<bool>() == true;
            var archived = (await client.ArchiveConversationAsync(id, true))?["archivedAt"]?.GetValue<long>() > 0;
            var hidden = !(await client.ListConversationsAsync(false))
                .Any(item => item["id"]?.GetValue<string>() == id);
            var shown = (await client.ListConversationsAsync(true))
                .Any(item => item["id"]?.GetValue<string>() == id);
            lines.Add($"pin: {pinned}");
            lines.Add($"archive: {archived}; hidden: {hidden}; shown when asked: {shown}");
            deleted = await client.DeleteConversationAsync(id);
            remaining = (await client.ListConversationsAsync()).Count;
        }
        catch (Exception error)
        {
            lines.Add($"error: {error.Message}");
        }

        lines.Add($"created: {(id.Length > 0 ? "ok" : "FAIL")}");
        lines.Add($"renamed: {renamed}");
        lines.Add($"search hits: {hits.Count}");
        lines.Add($"export has title: {exported.Contains("\"Groceries\"")}");
        lines.Add($"delete: {deleted}");
        lines.Add($"conversations left: {remaining}");
        File.WriteAllLines(path, lines);
        Application.Current.Shutdown();
    }

    public async Task PcCheckAsync(string path)
    {
        var settings = new SettingsStore();
        var current = settings.Load();
        current.UseBridge = false;
        settings.Save(current);

        outputPath = path;
        autoApproval = "allow";
        await ConnectAsync();
        await SendAsync("open notepad");
        await SendAsync("type hello in notepad");
        WriteLog();
        Application.Current.Shutdown();
    }

    public async Task PairAsync(string url, string code, string path)
    {
        var (ok, token, refresh) = await PostAsync(url, "/pair", new { code });
        if (ok && token.Length > 0)
        {
            CredentialStore.Write("hopa.bridge.token", token);
            CredentialStore.Write("hopa.bridge.refresh", refresh);
            var settings = new SettingsStore();
            var current = settings.Load();
            current.BridgeUrl = url;
            current.UseBridge = true;
            settings.Save(current);
        }

        File.WriteAllLines(path, new[]
        {
            $"pair: {(ok && token.Length > 0 ? "ok" : "FAIL")}",
            $"refresh stored: {refresh.Length > 0}",
        });
        Application.Current.Shutdown();
    }

    public async Task StaleCheckAsync(string url, string path)
    {
        var staleToken = CredentialStore.Read("hopa.bridge.token");
        var refresh = CredentialStore.Read("hopa.bridge.refresh");
        var (ok, newToken, newRefresh) = await PostAsync(url, "/refresh", new { refresh });
        // Keep the old token (now rejected) and hand the sidecar the rotated refresh.
        CredentialStore.Write("hopa.bridge.refresh", newRefresh);
        outputPath = path;
        autoApproval = "allow";
        await ConnectAsync();
        await SendAsync("open settings on the phone");
        Log($"stale check: rotation={(ok && newToken.Length > 0 ? "ok" : "FAIL")} " +
            $"token_changed={newToken != staleToken}");
        WriteLog();
        Application.Current.Shutdown();
    }

    private static async Task<(bool Ok, string Token, string Refresh)> PostAsync(
        string url,
        string path,
        object body)
    {
        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
        var payload = JsonSerializer.Serialize(body);
        var response = await http.PostAsync(
            url.TrimEnd('/') + path,
            new StringContent(payload, Encoding.UTF8, "application/json"));
        var text = await response.Content.ReadAsStringAsync();
        var node = response.IsSuccessStatusCode ? JsonNode.Parse(text) as JsonObject : null;
        return (
            response.IsSuccessStatusCode,
            node?["token"]?.GetValue<string>() ?? "",
            node?["refresh"]?.GetValue<string>() ?? "");
    }
}
