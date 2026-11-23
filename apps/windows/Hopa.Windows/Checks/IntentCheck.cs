using System.IO;
using System.Text.Json.Nodes;
using Hopa.Windows.Device;

namespace Hopa.Windows.Checks;

/// <summary>
/// P3 gate for the intent tier: a settings page opens through a URI, the host
/// refuses a scheme it has no reason to hand to the OS, and the observation is a
/// real Settings window afterwards.
/// </summary>
public static class IntentCheck
{
    public static string Run(string outputPath)
    {
        var lines = new List<string>();
        using var device = new WindowsDevice();
        try
        {
            lines.Add("scheme refused: " +
                      Refusal(() => device.OpenLink("file:///C:/Windows/System32/notepad.exe")));
            lines.Add("scheme refused: " +
                      Refusal(() => device.OpenLink("shell:startup")));
            lines.Add("open: " + device.OpenLink("ms-settings:network-wifi"));
            Thread.Sleep(800);
            var (observation, nodes) = device.Observe();
            lines.Add($"observe: app={observation["app"]} nodes={nodes}");
            lines.Add("foreground: " + device.ForegroundApp());
        }
        catch (Exception error)
        {
            lines.Add($"error: {error.Message}");
        }

        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath)) ?? ".");
        File.WriteAllLines(outputPath, lines);
        return string.Join(Environment.NewLine, lines);
    }

    private static string Refusal(Action action)
    {
        try
        {
            action();
            return "FAIL (it was allowed)";
        }
        catch (Exception error)
        {
            return "refused: " + error.Message;
        }
    }
}
