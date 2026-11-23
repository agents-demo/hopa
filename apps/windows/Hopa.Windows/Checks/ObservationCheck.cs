using System.Diagnostics;
using System.IO;
using System.Text.Json.Nodes;
using Hopa.Windows.Device;

namespace Hopa.Windows.Checks;

/// <summary>
/// W3 checks that need a real desktop but only one app: hash stability across two
/// observations, pattern-first tap, text through ValuePattern, and the caps that
/// keep a huge tree from flooding the turn.
/// </summary>
public static class ObservationCheck
{
    public static string Run(string outputPath)
    {
        var lines = new List<string>();
        using var device = new WindowsDevice();
        try
        {
            lines.Add("blind type: " + Refusal(() => device.Act("type", new JsonObject { ["text"] = "blind" })));
            lines.Add("launch: " + device.Act("launch", new JsonObject { ["app"] = "notepad" }));
            Thread.Sleep(1500);

            var (first, nodes) = device.Observe();
            var (second, _) = device.Observe();
            var hash1 = first["hash"]?.GetValue<string>() ?? "";
            var hash2 = second["hash"]?.GetValue<string>() ?? "";
            lines.Add($"observe: app={first["app"]} nodes={nodes} density={first["density"]} truncated={first["truncated"]}");
            lines.Add($"hash stable across two observations: {hash1 == hash2} ({hash1})");

            var refId = device.FirstEditableRef();
            if (refId == null)
            {
                lines.Add("editable field: none");
            }
            else
            {
                lines.Add("tap: " + device.Act("tap", new JsonObject { ["ref"] = refId }));
                lines.Add("type: " + device.Act("type", new JsonObject
                {
                    ["ref"] = refId,
                    ["text"] = "HOPA w3 " + DateTime.UtcNow.ToString("HHmmss"),
                }));
                lines.Add($"readback: '{device.ReadRefValue(refId)}'");
            }

            var png = device.CaptureWindow();
            lines.Add(png == null
                ? "screenshot: none"
                : $"screenshot: {png.Length} bytes");

            // A calculator button is where the pattern path shows itself: Invoke
            // or Toggle, not a mouse click at coordinates.
            lines.Add("launch calc: " + device.Act("launch", new JsonObject { ["app"] = "calc" }));
            Thread.Sleep(1500);
            var (calc, calcNodes) = device.Observe();
            lines.Add($"calc observe: app={calc["app"]} nodes={calcNodes}");
            var buttonRef = FirstClickable(calc["tree"] as JsonObject);
            lines.Add(buttonRef == null
                ? "calc tap: no clickable node in the tree"
                : "calc tap: " + device.Act("tap", new JsonObject { ["ref"] = buttonRef }));
        }
        catch (Exception error)
        {
            lines.Add($"error: {error.Message}");
        }
        finally
        {
            foreach (var process in Process.GetProcessesByName("notepad"))
            {
                try
                {
                    process.CloseMainWindow();
                    process.WaitForExit(2000);
                    if (!process.HasExited)
                    {
                        process.Kill();
                    }
                }
                catch
                {
                    // Closing the test app is a courtesy, not the result.
                }
            }
        }

        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath)) ?? ".");
        File.WriteAllLines(outputPath, lines);
        return string.Join(Environment.NewLine, lines);
    }


    /// <summary>The first enabled, visible node the tree marks clickable.</summary>
    private static string? FirstClickable(JsonObject? node)
    {
        if (node == null)
        {
            return null;
        }

        var clickable = node["clickable"]?.GetValue<bool>() ?? false;
        var enabled = node["enabled"]?.GetValue<bool>() ?? false;
        var visible = node["visible"]?.GetValue<bool>() ?? false;
        if (clickable && enabled && visible)
        {
            return node["ref"]?.GetValue<string>();
        }

        if (node["children"] is JsonArray children)
        {
            foreach (var child in children)
            {
                var found = FirstClickable(child as JsonObject);
                if (found != null)
                {
                    return found;
                }
            }
        }

        return null;
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
