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













    public async Task DraftCheckAsync(string path)
    {
        await ConnectAsync();
        var lines = new List<string>();
        var firstId = chatController?.CurrentId;
        if (client == null || firstId == null)
        {
            lines.Add("draft round-trip: FAIL (not connected)");
            File.WriteAllLines(path, lines);
            Application.Current.Shutdown();
            return;
        }

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
                var turn = client.StartTurnAsync("slow turn please", chatController?.CurrentId);
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
