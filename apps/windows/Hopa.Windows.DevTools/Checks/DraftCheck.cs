using System.IO;
using Hopa.Windows.Ui.Chat;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>Draft text survives a conversation switch and does not leak across one.</summary>
internal static class DraftCheck
{
    public static async Task Run(MainWindow window, string path)
    {
        var tools = window.Tools;
        await tools.ConnectAsync();
        var lines = new List<string>();
        var firstId = tools.CurrentConversationId;
        if (tools.Engine == null || firstId == null)
        {
            lines.Add("draft round-trip: FAIL (not connected)");
            File.WriteAllLines(path, lines);
            tools.Shutdown();
            return;
        }

        var other = tools.Conversations.FirstOrDefault(item => item.Id != firstId);
        if (other == null)
        {
            var created = await tools.Engine.CreateConversationAsync();
            var id = created?["id"]?.GetValue<string>();
            if (id != null)
            {
                tools.Conversations.Add(ConversationRow.From(created!));
                other = tools.Conversations.First(item => item.Id == id);
            }
        }

        if (other == null)
        {
            lines.Add("draft round-trip: FAIL (no second conversation)");
            File.WriteAllLines(path, lines);
            tools.Shutdown();
            return;
        }

        tools.ComposerText = "draft one";
        await tools.SelectAsync(other.Id);
        var cleared = tools.ComposerText;
        await tools.SelectAsync(firstId);
        var restored = tools.ComposerText;
        lines.Add($"second conversation: {other.Id}");
        lines.Add($"composer after switch: '{cleared}' (expected '')");
        lines.Add($"draft restored: '{restored}' (expected 'draft one')");
        lines.Add($"draft round-trip: {(cleared.Length == 0 && restored == "draft one" ? "ok" : "FAIL")}");
        File.WriteAllLines(path, lines);
        tools.Shutdown();
    }
}
