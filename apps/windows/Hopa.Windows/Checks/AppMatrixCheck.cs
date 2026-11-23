using System.IO;
using System.Text.Json.Nodes;
using Hopa.Windows.Device;

namespace Hopa.Windows.Checks;

/// <summary>
/// Launches the apps the product claims to drive, observes each one, keeps a
/// screenshot, and types into Notepad. Each app is independent: one failure does
/// not stop the transcript.
/// </summary>
public static class AppMatrixCheck
{
    public static async Task<string> Run(string path)
    {
        var lines = new List<string>();
        var directory = Path.GetDirectoryName(Path.GetFullPath(path)) ?? ".";
        using var device = new WindowsDevice();
        try
        {
            device.Act("type", new JsonObject { ["text"] = "blind" });
            lines.Add("blind type: FAIL (it was allowed)");
        }
        catch (Exception error)
        {
            lines.Add($"blind type refused: {error.Message}");
        }

        foreach (var app in new[] { "notepad", "calc", "explorer", "chrome", "code" })
        {
            lines.Add($"--- {app}");
            try
            {
                lines.Add(device.Act("launch", new JsonObject { ["app"] = app }));
                await Task.Delay(1500);
                var (observation, nodes) = device.Observe();
                var foreground = observation["app"]?.GetValue<string>() ?? "";
                lines.Add($"observe: app={foreground} nodes={nodes}");
                var png = device.CaptureWindow();
                if (png != null)
                {
                    var shot = Path.Combine(directory, $"windows-matrix-{app}.png");
                    File.WriteAllBytes(shot, png);
                    lines.Add($"screenshot: {shot} ({png.Length} bytes)");
                }
                else
                {
                    lines.Add("screenshot: none");
                }

                if (app == "notepad")
                {
                    if (!foreground.Contains("notepad", StringComparison.OrdinalIgnoreCase))
                    {
                        lines.Add($"type skipped: foreground={foreground}, not Notepad");
                    }
                    else
                    {
                        var refId = device.FirstEditableRef();
                        if (refId == null)
                        {
                            lines.Add("type: no editable field in the observation");
                        }
                        else
                        {
                            device.Act("tap", new JsonObject { ["ref"] = refId });
                            device.Act("type", new JsonObject
                            {
                                ["ref"] = refId,
                                ["text"] = "HOPA matrix 2026",
                            });
                            lines.Add($"type via {refId}: readback='{device.ReadRefValue(refId)}'");
                        }
                    }
                }
            }
            catch (Exception error)
            {
                lines.Add($"error: {error.Message}");
            }
        }

        File.WriteAllLines(path, lines);
        return string.Join(Environment.NewLine, lines);
    }
}
