using System.IO;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>Starts a slow turn, cancels it and checks the answer says it stopped.</summary>
internal static class CancelCheck
{
    public static async Task Run(MainWindow window, string path)
    {
        var tools = window.Tools;
        tools.SetAutomationOutput(path, "allow");
        await tools.ConnectAsync();
        var lines = new List<string>();
        if (tools.Engine == null)
        {
            lines.Add("cancel check: FAIL (not connected)");
        }
        else
        {
            try
            {
                var turn = tools.Engine.StartTurnAsync("slow turn please", tools.CurrentConversationId);
                await Task.Delay(1000);
                tools.Engine.CancelTurn();
                var (answer, _, _, steps, _, _, _) = await turn;
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
        tools.Shutdown();
    }
}
