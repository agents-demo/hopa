using System.IO;
using System.Text.Json.Nodes;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>Creates, renames, searches, pins, archives, exports and deletes one conversation.</summary>
internal static class HistoryCheck
{
    public static async Task Run(MainWindow window, string path)
    {
        var tools = window.Tools;
        tools.SetAutomationOutput(path, null);
        await tools.ConnectAsync();
        var lines = new List<string>();
        if (tools.Engine == null)
        {
            lines.Add("history check: FAIL (not connected)");
            File.WriteAllLines(path, lines);
            tools.Shutdown();
            return;
        }

        var engine = tools.Engine;
        var created = await engine.CreateConversationAsync();
        var id = created?["id"]?.GetValue<string>() ?? "";
        string renamed = "FAIL";
        var hits = new List<JsonObject>();
        var exported = "";
        var deleted = false;
        var remaining = -1;
        try
        {
            renamed = await engine.RenameConversationAsync(id, "Groceries") is { } r
                ? r["title"]?.GetValue<string>() ?? "FAIL"
                : "FAIL";
            hits = await engine.SearchConversationsAsync("Grocer");
            exported = await engine.ExportConversationAsync(id);
            var pinned = (await engine.PinConversationAsync(id, true))?["pinned"]?.GetValue<bool>() == true;
            var archived = (await engine.ArchiveConversationAsync(id, true))?["archivedAt"]?.GetValue<long>() > 0;
            var hidden = !(await engine.ListConversationsAsync(false))
                .Any(item => item["id"]?.GetValue<string>() == id);
            var shown = (await engine.ListConversationsAsync(true))
                .Any(item => item["id"]?.GetValue<string>() == id);
            lines.Add($"pin: {pinned}");
            lines.Add($"archive: {archived}; hidden: {hidden}; shown when asked: {shown}");
            deleted = await engine.DeleteConversationAsync(id);
            remaining = (await engine.ListConversationsAsync()).Count;
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
        tools.Shutdown();
    }
}
