using System.Diagnostics;
using System.IO;
using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Device;

namespace Hopa.Windows.Checks;

/// <summary>
/// P2 gate: the PC adapter as a full <c>DevicePort</c> — launch proves the
/// foreground, observation hashes are stable, a ref is required for typing, a
/// stale ref is refused, a screenshot is a frame, the Start menu is a real app
/// list, and stopping an app proves it left.
///
/// Every step is independent: a refusal is recorded and the run continues, so a
/// locked or busy desktop still produces a useful transcript.
///
/// The lock-screen and elevation refusals need a human in front of the machine;
/// use <see cref="RunWait"/> and the steps in docs/guides/windows/p2-testing.md.
/// The no-tree rule is unit-tested in Hopa.Windows.Tests.
/// </summary>
public static class DevicePortCheck
{
    public static string Run(string outputPath)
    {
        var lines = new List<string>();
        var scratch = Path.Combine(Path.GetTempPath(), "hopa-p2-scratch.txt");
        var notepadRunning = Process.GetProcessesByName("notepad").Length > 0;
        using var device = new WindowsDevice();
        var knownNotepad = ProcessIds("notepad");
        var knownCalc = ProcessIds("CalculatorApp").Concat(ProcessIds("calc")).ToHashSet();
        var spawnedNotepad = new List<int>();
        var spawnedCalc = new List<int>();

        lines.Add("adapter: full DevicePort contract");

        lines.Add("type without ref: " +
                  Refusal(() => device.Act("type", new JsonObject { ["text"] = "blind" })));

        lines.Add("stale ref: " +
                  Refusal(() => device.Act("type", new JsonObject
                  {
                      ["ref"] = "e9999",
                      ["text"] = "x",
                  })));

        try
        {
            var apps = device.Apps();
            lines.Add($"apps: {apps.Count} from the Start menu");
            foreach (var entry in apps.Take(5))
            {
                lines.Add($"  {entry.Label} -> {entry.Package}");
            }
        }
        catch (Exception error)
        {
            lines.Add($"apps: failed: {error.Message}");
        }

        try
        {
            var png = device.CaptureWindow();
            lines.Add(png == null
                ? "screenshot: none (protected or not capturable)"
                : $"screenshot: {png.Length} bytes");
        }
        catch (Exception error)
        {
            lines.Add($"screenshot: failed: {error.Message}");
        }

        lines.Add("stop a missing app: " +
                  Refusal(() => device.Act("stop", new JsonObject { ["app"] = "hopa-no-such-app" })));

        // Launch with a scratch document: Windows 11 Notepad restores previous
        // tabs, and typing into somebody's real file is not a test.
        var launched = !notepadRunning;
        if (notepadRunning)
        {
            // Windows 11 Notepad has tabs and session restore. Launching into an
            // open window would add our scratch tab to the person's session, so
            // the read-back is skipped rather than risk their document.
            lines.Add("notepad: skipped — a Notepad window is already open; close it and rerun for the read-back");
        }
        else
        {
            try
            {
                File.WriteAllText(scratch, "");
                lines.Add("launch notepad: " + device.Act("launch", new JsonObject { ["app"] = scratch }));
                Thread.Sleep(1500);
            }
            catch (Exception error)
            {
                launched = false;
                lines.Add($"launch notepad: failed: {error.Message}");
                lines.Add("foreground: " + device.ForegroundApp());
            }
            finally
            {
                // Track it even when the launch threw: a window may exist without
                // having come forward, and cleanup must still close it.
                TrackNew("notepad", knownNotepad, spawnedNotepad);
            }
        }

        if (launched)
        {
            try
            {
                var (first, nodes) = device.Observe();
                var (second, _) = device.Observe();
                var hash1 = first["hash"]?.GetValue<string>() ?? "";
                var hash2 = second["hash"]?.GetValue<string>() ?? "";
                lines.Add($"observe: app={first["app"]} nodes={nodes} " +
                          $"density={first["density"]} truncated={first["truncated"]}");
                lines.Add($"hash stable: {hash1 == hash2} ({Short(hash1)})");
            }
            catch (Exception error)
            {
                lines.Add($"observe: failed: {error.Message}");
            }

            // Stop before typing: it proves close-and-leave with no save prompt.
            lines.Add("stop notepad: " +
                      RefusalOr(() => device.Act("stop", new JsonObject { ["app"] = "notepad" })));
            lines.Add("foreground after stop: " + device.ForegroundApp());

            try
            {
                try
                {
                    lines.Add("launch notepad again: " +
                              device.Act("launch", new JsonObject { ["app"] = scratch }));
                    Thread.Sleep(1500);
                }
                finally
                {
                    TrackNew("notepad", knownNotepad, spawnedNotepad);
                }

                var (again, againNodes) = device.Observe();
                lines.Add($"observe again: app={again["app"]} nodes={againNodes}");

                var refId = device.FirstEditableRef();
                if (refId == null)
                {
                    lines.Add("editable: none");
                }
                else
                {
                    lines.Add("tap: " + device.Act("tap", new JsonObject { ["ref"] = refId }));
                    var typed = "HOPA p2 " + DateTime.UtcNow.ToString("HHmmss");
                    lines.Add("type: " + device.Act("type", new JsonObject
                    {
                        ["ref"] = refId,
                        ["text"] = typed,
                    }));
                    var readback = device.ReadRefValue(refId);
                    lines.Add($"readback: '{readback}'");
                    lines.Add($"readback matches: {readback == typed}");
                }
            }
            catch (Exception error)
            {
                lines.Add($"second launch: failed: {error.Message}");
            }
        }

        try
        {
            try
            {
                lines.Add("launch calc: " + device.Act("launch", new JsonObject { ["app"] = "calc" }));
                Thread.Sleep(1500);
            }
            finally
            {
                TrackNew("CalculatorApp", knownCalc, spawnedCalc);
                TrackNew("calc", knownCalc, spawnedCalc);
            }

            var (calc, calcNodes) = device.Observe();
            lines.Add($"calc observe: app={calc["app"]} nodes={calcNodes}");
            var buttonRef = FirstClickable(calc["tree"] as JsonObject);
            lines.Add(buttonRef == null
                ? "calc tap: no clickable node in the tree"
                : "calc tap: " + device.Act("tap", new JsonObject { ["ref"] = buttonRef }));
        }
        catch (Exception error)
        {
            lines.Add($"calc: failed: {error.Message}");
        }

        lines.Add("no-tree rule: ObservationRules.IsTreeOnlyRoot (unit test)");
        lines.Add("lock/elevated: manual, see docs/guides/windows/p2-testing.md");

        CloseTracked(spawnedNotepad);
        CloseTracked(spawnedCalc);
        // The scratch file stays on disk on purpose: Windows 11 Notepad restores
        // its last tab, and a deleted path would open a "Cannot find the file"
        // dialog on the next launch. One fixed name means one valid tab, not many.
        lines.Add("scratch: " + scratch + " (kept so Notepad's tab restore stays valid)");

        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath)) ?? ".");
        File.WriteAllLines(outputPath, lines);
        return string.Join(Environment.NewLine, lines);
    }

    /// <summary>
    /// Watches the foreground until it becomes unreadable: a lock screen, the
    /// secure desktop, or an elevated window. It stops on the first refusal, so
    /// there is no race with a timer: lock the machine whenever you are ready.
    /// </summary>
    public static string RunWait(string outputPath, int seconds, string mode = "lock")
    {
        var wantElevation = mode.Equals("elevated", StringComparison.OrdinalIgnoreCase);
        var lines = new List<string>
        {
            wantElevation
                ? $"watching for an elevated window for up to {seconds}s — approve the UAC prompt and leave the app in front"
                : $"watching for a refusal for up to {seconds}s — lock the screen whenever you are ready",
        };
        string? reason = null;
        var sawSecure = false;
        using (var device = new WindowsDevice())
        {
            var deadline = DateTime.UtcNow.AddSeconds(Math.Max(1, seconds));
            while (DateTime.UtcNow < deadline)
            {
                var candidate = device.UnreadableReason();
                if (candidate != null)
                {
                    var isElevation = candidate.Contains("runs elevated", StringComparison.OrdinalIgnoreCase);
                    if (!wantElevation || isElevation)
                    {
                        reason = candidate;
                        break;
                    }

                    // The UAC consent dialog is the secure desktop. It is the same
                    // boundary as the lock screen and must not end this run: keep
                    // polling until the approved, elevated window is in front.
                    if (!sawSecure)
                    {
                        sawSecure = true;
                        lines.Add("secure desktop seen (the consent dialog); still waiting for the elevated window");
                    }
                }

                Thread.Sleep(300);
            }

            lines.Add(reason != null
                ? "refused: " + reason
                : wantElevation
                    ? $"no elevated window within {seconds}s (foreground={device.ForegroundApp()})"
                    : $"no refusal within {seconds}s (foreground={device.ForegroundApp()})");
        }

        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath)) ?? ".");
        File.WriteAllLines(outputPath, lines);
        return string.Join(Environment.NewLine, lines);
    }

    private static string Short(string hash) => hash.Length <= 18 ? hash : hash[..18];

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

    private static string RefusalOr(Func<string> action)
    {
        try
        {
            return action();
        }
        catch (Exception error)
        {
            return "refused: " + error.Message;
        }
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

    /// <summary>Process IDs already running; the check never touches those.</summary>
    private static HashSet<int> ProcessIds(string name) =>
        Process.GetProcessesByName(name).Select(process =>
        {
            var id = process.Id;
            process.Dispose();
            return id;
        }).ToHashSet();

    /// <summary>Remember what the check started, so cleanup is scoped to it.</summary>
    private static void TrackNew(string name, HashSet<int> known, List<int> tracked)
    {
        foreach (var process in Process.GetProcessesByName(name))
        {
            try
            {
                if (known.Add(process.Id))
                {
                    tracked.Add(process.Id);
                }
            }
            finally
            {
                process.Dispose();
            }
        }
    }

    /// <summary>Cleanup only: close the processes this check started.</summary>
    private static void CloseTracked(IEnumerable<int> ids)
    {
        foreach (var id in ids)
        {
            try
            {
                using var process = Process.GetProcessById(id);
                if (!process.CloseMainWindow())
                {
                    process.Kill();
                    continue;
                }

                process.WaitForExit(1500);
                if (!process.HasExited)
                {
                    // The scratch document can be discarded; nothing of the person's is here.
                    process.Kill();
                }
            }
            catch
            {
                // Already gone, which is the point.
            }
        }
    }
}
