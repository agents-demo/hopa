using System.IO;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>Attaches a file, starts a turn with it and exports the conversation.</summary>
internal static class AttachCheck
{
    public static async Task Run(MainWindow window, string file, string path)
    {
        var tools = window.Tools;
        tools.SetAutomationOutput(path, null);
        await tools.ConnectAsync();
        var lines = new List<string>();
        if (tools.Engine == null)
        {
            lines.Add("attach check: FAIL (not connected)");
        }
        else
        {
            try
            {
                var attachment = await tools.Engine.AttachFileAsync(file);
                var name = attachment["name"]?.GetValue<string>() ?? "";
                var bytes = attachment["bytes"]?.GetValue<long>() ?? 0;
                var local = attachment["path"]?.GetValue<string>() ?? "";
                var created = await tools.Engine.CreateConversationAsync();
                var id = created?["id"]?.GetValue<string>() ?? "";
                await tools.Engine.StartTurnAsync($"attached {name}", id, attachment);
                var exported = await tools.Engine.ExportConversationAsync(id);
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
        tools.Shutdown();
    }
}
