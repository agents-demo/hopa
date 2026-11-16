using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using FlaUI.UIA3;

namespace Hopa.Windows;

/// <summary>
/// W3: the Windows device adapter. Observation is a real UI Automation tree with
/// pre-order refs, bounded depth, bounded text and a hash. Actions try the UIA
/// pattern first and fall back to the input stack. Every UIA call has a timeout:
/// a hung provider is reported, never allowed to freeze the turn.
/// </summary>
public sealed class WindowsDevice : IDisposable
{
    private static readonly TimeSpan CallTimeout = TimeSpan.FromMilliseconds(1500);
    private static readonly TimeSpan PropertyTimeout = TimeSpan.FromMilliseconds(700);

    private const int MaxNodes = 350;
    private const int MaxDepth = 14;

    private readonly UIA3Automation automation = new();
    private readonly Dictionary<string, AutomationElement> refs = new();
    private AutomationElement? root;
    private int counter;
    private int textChars;

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hwnd);

    [DllImport("user32.dll")]
    private static extern void keybd_event(byte virtualKey, byte scan, uint flags, UIntPtr extra);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hwnd, int command);

    [DllImport("user32.dll")]
    private static extern bool AttachThreadInput(uint attach, uint attachTo, bool attachFlag);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);

    [DllImport("user32.dll")]
    private static extern uint GetDpiForWindow(IntPtr hwnd);

    [DllImport("kernel32.dll")]
    private static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(IntPtr token, int infoClass, out int info, int length, out int returned);

    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr handle);

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    private static readonly string[] SecureProcesses =
    {
        "lockapp", "logonui", "winlogon", "screensaver",
    };

    /// <summary>The lock screen and the logon desktop refuse input by design.</summary>
    private bool IsSecureSurface(out string processName)
    {
        processName = "";
        var hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero)
        {
            return true;
        }

        var thread = GetWindowThreadProcessId(hwnd, out var pid);
        if (thread == 0 || pid == 0)
        {
            // The lock screen and the UAC desktop belong to Winlogon on another
            // desktop; a normal caller sees a zero handle or PID. That is the
            // boundary, not an app without a tree.
            return true;
        }

        try
        {
            processName = Process.GetProcessById((int)pid).ProcessName;
        }
        catch
        {
            // A process we cannot even name is not one we can drive.
            return true;
        }

        return SecureProcesses.Contains(processName.ToLowerInvariant());
    }

    /// <summary>
    /// The refusal the current foreground would produce, or null when it is
    /// usable. Cheap and read-only: it checks the process, never UI Automation,
    /// so a wait loop can poll it while the session locks.
    /// </summary>
    public string? UnreadableReason()
    {
        try
        {
            RefuseSecureSurface();
            RefuseElevatedBoundary();
            return null;
        }
        catch (InvalidOperationException error)
        {
            return error.Message;
        }
    }

    private void RefuseSecureSurface()
    {
        if (IsSecureSurface(out var processName))
        {
            throw new InvalidOperationException(
                processName.Length == 0
                    ? "the screen is locked or secure; HOPA cannot see or touch it"
                    : $"the screen is '{processName}' (locked or secure); HOPA cannot see or touch it");
        }
    }

    /// <summary>
    /// A window owned by an elevated process is behind a boundary Windows does
    /// not let a normal process cross. Say so, with the reason and the setup page.
    /// </summary>
    private void RefuseElevatedBoundary()
    {
        var hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero)
        {
            return;
        }

        GetWindowThreadProcessId(hwnd, out var pid);
        if (pid == 0)
        {
            return;
        }

        var targetElevated = IsProcessElevated((int)pid);
        if (targetElevated == true && IsProcessElevated(Environment.ProcessId) != true)
        {
            var name = "";
            try
            {
                name = Process.GetProcessById((int)pid).ProcessName;
            }
            catch
            {
                // The name is a courtesy; the refusal does not depend on it.
            }

            throw new InvalidOperationException(
                $"'{name}' runs elevated and HOPA does not; Windows blocks input across that boundary. " +
                "Install the signed uiAccess helper (docs/guides/windows/uiaccess.md) or run HOPA elevated on purpose.");
        }
    }

    /// <summary>null when the token cannot be read, which is not an elevation answer.</summary>
    private static bool? IsProcessElevated(int pid)
    {
        const uint queryLimited = 0x1000;
        const uint tokenQuery = 0x0008;
        const int tokenElevation = 20;

        var process = OpenProcess(queryLimited, false, (uint)pid);
        if (process == IntPtr.Zero)
        {
            return null;
        }

        try
        {
            if (!OpenProcessToken(process, tokenQuery, out var token))
            {
                return null;
            }

            try
            {
                return GetTokenInformation(token, tokenElevation, out var info, sizeof(int), out _)
                    ? info != 0
                    : null;
            }
            finally
            {
                CloseHandle(token);
            }
        }
        finally
        {
            CloseHandle(process);
        }
    }

    public System.Windows.Size ScreenSize()
    {
        var width = (int)System.Windows.SystemParameters.PrimaryScreenWidth;
        var height = (int)System.Windows.SystemParameters.PrimaryScreenHeight;
        return new System.Windows.Size(width, height);
    }

    public string ForegroundApp()
    {
        var hwnd = GetForegroundWindow();
        GetWindowThreadProcessId(hwnd, out var pid);
        try
        {
            return Process.GetProcessById((int)pid).ProcessName;
        }
        catch
        {
            return "";
        }
    }

    /// <summary>
    /// Open a URI through the shell. Only the schemes an assistant has a reason
    /// to use are allowed: a web page or a Windows settings page. Anything else
    /// is refused instead of handing an arbitrary handler to the OS.
    /// </summary>
    public string OpenLink(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri))
        {
            throw new InvalidOperationException($"'{url}' is not an absolute URI");
        }

        var scheme = uri.Scheme.ToLowerInvariant();
        if (scheme is not ("http" or "https" or "ms-settings"))
        {
            throw new InvalidOperationException(
                $"the '{scheme}' scheme is not allowed; only http, https and ms-settings");
        }

        Process.Start(new ProcessStartInfo { FileName = url, UseShellExecute = true });
        Thread.Sleep(900);
        if (scheme == "ms-settings")
        {
            // The Settings app is a packaged app; wait for its window and bring
            // it forward so the observation can actually verify the page.
            var handle = WaitForSettingsWindow(TimeSpan.FromSeconds(10));
            if (handle != IntPtr.Zero)
            {
                ForceForeground(handle);
                Thread.Sleep(500);
            }
        }

        return $"opened {url} (foreground={ForegroundApp()})";
    }

    /// <summary>One app the Start menu offers: a launchable target and a label.</summary>
    public sealed record AppEntry(string Package, string Label);

    private List<AppEntry>? appsCache;
    private DateTime appsCachedAt;

    /// <summary>
    /// The apps a person can actually start, read from the Start menu shortcuts.
    /// A shortcut is only offered when its target exists and is an executable;
    /// the list is cached for a minute because the shell walk is not free.
    /// </summary>
    public List<AppEntry> Apps()
    {
        if (appsCache != null && DateTime.UtcNow - appsCachedAt < TimeSpan.FromMinutes(1))
        {
            return appsCache;
        }

        var found = new Dictionary<string, AppEntry>(StringComparer.OrdinalIgnoreCase);
        object? shell = null;
        try
        {
            var type = System.Type.GetTypeFromProgID("WScript.Shell");
            shell = type == null ? null : Activator.CreateInstance(type);
            foreach (var root in StartMenuRoots())
            {
                if (!Directory.Exists(root))
                {
                    continue;
                }

                IEnumerable<string> files;
                try
                {
                    files = Directory.GetFiles(root, "*.lnk", SearchOption.AllDirectories);
                }
                catch
                {
                    continue;
                }

                foreach (var file in files)
                {
                    try
                    {
                        var label = Path.GetFileNameWithoutExtension(file);
                        if (label.Length == 0 ||
                            label.Contains("uninstall", StringComparison.OrdinalIgnoreCase))
                        {
                            continue;
                        }

                        var target = ShortcutTarget(shell, file);
                        if (target.Length == 0 ||
                            !target.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) ||
                            !File.Exists(target))
                        {
                            continue;
                        }

                        found.TryAdd(target, new AppEntry(target, label));
                    }
                    catch
                    {
                        // One broken shortcut is not a reason to lose the list.
                    }
                }
            }
        }
        finally
        {
            if (shell != null)
            {
                System.Runtime.InteropServices.Marshal.ReleaseComObject(shell);
            }
        }

        appsCache = found.Values
            .OrderBy(entry => entry.Label, StringComparer.CurrentCultureIgnoreCase)
            .Take(200)
            .ToList();
        appsCachedAt = DateTime.UtcNow;
        return appsCache;
    }

    private static IEnumerable<string> StartMenuRoots()
    {
        yield return Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu);
        yield return Environment.GetFolderPath(Environment.SpecialFolder.StartMenu);
    }

    private static string ShortcutTarget(object? shell, string path)
    {
        if (shell == null)
        {
            return "";
        }

        try
        {
            // dynamic, not reflection: a shortcut is a COM object reached through
            // IDispatch, and InvokeMember on the RCW does not dispatch it.
            dynamic dynamicShell = shell;
            dynamic shortcut = dynamicShell.CreateShortcut(path);
            var target = (string)(shortcut.TargetPath ?? "");
            System.Runtime.InteropServices.Marshal.ReleaseComObject(shortcut);
            return target;
        }
        catch
        {
            return "";
        }
    }

    /// <summary>
    /// Close an app by asking its window to close. A save prompt or a stubborn
    /// process is reported, never killed: an unsaved document is the person's.
    /// </summary>
    public string Stop(string app)
    {
        var needle = Path.GetFileNameWithoutExtension(app.Trim());
        if (needle.Length == 0)
        {
            throw new InvalidOperationException("stop needs an app");
        }

        var processes = Process.GetProcessesByName(needle);
        if (processes.Length == 0)
        {
            throw new InvalidOperationException($"'{app}' is not running");
        }

        var asked = 0;
        foreach (var process in processes)
        {
            try
            {
                if (process.CloseMainWindow())
                {
                    asked += 1;
                    process.WaitForExit(3000);
                }
            }
            catch
            {
                // The process may have exited between enumeration and the close.
            }
            finally
            {
                process.Dispose();
            }
        }

        if (asked == 0)
        {
            throw new InvalidOperationException($"'{app}' has no window to close");
        }

        Thread.Sleep(300);
        var still = Process.GetProcessesByName(needle);
        var remaining = still.Length;
        foreach (var process in still)
        {
            process.Dispose();
        }

        if (remaining > 0)
        {
            throw new InvalidOperationException(
                $"'{app}' is still running; it may be asking to save a document");
        }

        return $"stopped {app}";
    }

    /// <summary>Builds the observation JSON the Kotlin contract decodes.</summary>
    public (JsonObject Observation, int Nodes) Observe()
    {
        RefuseSecureSurface();
        RefuseElevatedBoundary();
        counter = 0;
        textChars = 0;
        refs.Clear();
        root = ForegroundElement();
        var lines = new List<string>();
        var truncated = false;
        var tree = root == null
            ? Node("root", "root", "", "", null, false, true, false, true, false, false, new List<JsonObject>())
            : Walk(root, 0, lines, ref truncated);
        var app = ForegroundApp();
        var screen = ScreenSize();
        var text = ObservationRules.JoinText(lines, out var textTruncated);
        if (ObservationRules.IsTreeOnlyRoot(counter, text))
        {
            throw new InvalidOperationException(
                $"'{app}' exposes no UI Automation tree; HOPA cannot see its controls");
        }

        var dpi = DpiFor(GetForegroundWindow());
        var observation = new JsonObject
        {
            ["schemaVersion"] = "1",
            ["id"] = $"win-{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}",
            ["timestamp"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
            ["displayId"] = 0,
            ["windowId"] = "active",
            ["rotation"] = 0,
            ["density"] = Math.Round(dpi / 96.0, 2),
            ["screenSize"] = new JsonObject
            {
                ["width"] = (int)screen.Width,
                ["height"] = (int)screen.Height,
            },
            ["focus"] = "",
            ["text"] = text,
            ["tree"] = tree,
            ["screenshotRef"] = "",
            ["app"] = app,
            ["hash"] = ObservationRules.Hash(app, (int)screen.Width, (int)screen.Height, lines),
            ["truncated"] = truncated || textTruncated || counter >= MaxNodes,
        };
        return (observation, refs.Count);
    }

    private static double DpiFor(IntPtr hwnd) => hwnd == IntPtr.Zero ? 96 : Math.Max(96, GetDpiForWindow(hwnd));

    public string Act(string op, JsonObject message)
    {
        RefuseSecureSurface();
        RefuseElevatedBoundary();
        var point = PointFor(message);
        var screenPoint = new System.Drawing.Point(point.X, point.Y);
        switch (op)
        {
            case "tap":
                return Tap(point, message);
            case "doubleTap":
                Mouse.DoubleClick(screenPoint);
                return $"double-clicked {point.X},{point.Y}";
            case "longPress":
                Mouse.MoveTo(screenPoint);
                Mouse.Down(MouseButton.Left);
                Thread.Sleep(700);
                Mouse.Up(MouseButton.Left);
                return $"long-pressed {point.X},{point.Y}";
            case "type":
                return Type(message);
            case "swipe":
                return Swipe(message);
            case "key":
                return Key(message);
            case "launch":
                var app = message["app"]?.GetValue<string>() ?? "";
                if (app.Length == 0)
                {
                    throw new InvalidOperationException("launch needs an app");
                }

                return Launch(app);
            case "stop":
                var target = message["app"]?.GetValue<string>() ?? "";
                if (target.Length == 0)
                {
                    throw new InvalidOperationException("stop needs an app");
                }

                return Stop(target);
            default:
                throw new InvalidOperationException($"the Windows adapter cannot '{op}' yet");
        }
    }

    public void Dispose() => automation.Dispose();

    /// <summary>Runs one UIA call with a deadline. A hung provider is an error,
    /// not a freeze of the whole turn.</summary>
    private static T Call<T>(Func<T> work, string what, TimeSpan? timeout = null)
    {
        var task = Task.Run(work);
        if (!task.Wait(timeout ?? CallTimeout))
        {
            throw new TimeoutException(
                $"UI Automation did not answer '{what}' within {(timeout ?? CallTimeout).TotalMilliseconds:0} ms");
        }

        return task.Result;
    }

    private static void Call(Action work, string what, TimeSpan? timeout = null) =>
        Call(() =>
        {
            work();
            return true;
        }, what, timeout);

    private static T Property<T>(Func<T> read, T fallback) =>
        Call(read, "a property read", PropertyTimeout) is { } value ? value : fallback;

    private AutomationElement? ForegroundElement()
    {
        try
        {
            var hwnd = GetForegroundWindow();
            return hwnd == IntPtr.Zero ? null : automation.FromHandle(hwnd);
        }
        catch
        {
            return null;
        }
    }

    private JsonObject Walk(AutomationElement element, int depth, List<string> lines, ref bool truncated)
    {
        var refId = $"e{++counter}";
        var controlType = Property(() => element.Properties.ControlType.ValueOrDefault.ToString(), "Unknown");
        var name = ObservationRules.Cap(Property(() => element.Properties.Name.ValueOrDefault ?? "", ""));
        var automationId = Property(() => element.Properties.AutomationId.ValueOrDefault ?? "", "");
        var isPassword = Property(() => element.Properties.IsPassword.ValueOrDefault, false);
        var enabled = Property(() => element.Properties.IsEnabled.ValueOrDefault, false);
        var offscreen = Property(() => element.Properties.IsOffscreen.ValueOrDefault, true);
        var focused = Property(() => element.Properties.HasKeyboardFocus.ValueOrDefault, false);
        var clickable = Property(
            () => element.Patterns.Invoke.IsSupported
                || element.Patterns.Toggle.IsSupported
                || element.Patterns.SelectionItem.IsSupported,
            false);
        var scrollable = Property(() => element.Patterns.Scroll.IsSupported, false);
        var bounds = Property<System.Drawing.Rectangle?>(() => element.BoundingRectangle, null);

        var type = isPassword ? "password" : controlType.ToLowerInvariant();
        if (!isPassword)
        {
            refs[refId] = element;
            if (name.Length > 0 && textChars < ObservationRules.MaxTotalChars)
            {
                lines.Add($"{refId} {type} {name}");
                textChars += name.Length;
            }
        }
        else
        {
            name = "";
            lines.Add($"{refId} password field (dropped)");
        }

        var children = new List<JsonObject>();
        if (depth >= MaxDepth)
        {
            truncated = true;
        }
        else if (counter >= MaxNodes)
        {
            truncated = true;
        }
        else
        {
            AutomationElement[] kids;
            try
            {
                kids = Call(() => element.FindAllChildren(), "children");
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
                truncated = true;
                kids = Array.Empty<AutomationElement>();
            }

            foreach (var child in kids)
            {
                if (counter >= MaxNodes)
                {
                    truncated = true;
                    break;
                }

                children.Add(Walk(child, depth + 1, lines, ref truncated));
            }
        }

        return Node(
            refId,
            type,
            name,
            automationId,
            bounds,
            clickable,
            enabled,
            false,
            !offscreen,
            scrollable,
            focused,
            children);
    }

    private static JsonObject Node(
        string refId,
        string type,
        string text,
        string id,
        System.Drawing.Rectangle? bounds,
        bool clickable,
        bool enabled,
        bool isChecked,
        bool visible,
        bool scrollable,
        bool focused,
        List<JsonObject> children)
    {
        var node = new JsonObject
        {
            ["ref"] = refId,
            ["type"] = type,
            ["text"] = text,
            ["description"] = "",
            ["id"] = id,
            ["clickable"] = clickable,
            ["enabled"] = enabled,
            ["checked"] = isChecked,
            ["scrollable"] = scrollable,
            ["visible"] = visible,
            ["focused"] = focused,
            ["children"] = new JsonArray(children.ToArray()),
        };
        node["bounds"] = bounds is { Width: > 0 } rect
            ? new JsonArray(rect.X, rect.Y, rect.X + rect.Width, rect.Y + rect.Height)
            : null;
        return node;
    }

    private (int X, int Y) PointFor(JsonObject message)
    {
        var refId = message["ref"]?.GetValue<string>();
        if (!string.IsNullOrEmpty(refId))
        {
            if (!refs.TryGetValue(refId, out var element))
            {
                throw new InvalidOperationException($"stale ref {refId}; observe again");
            }

            var bounds = Call(() => element.BoundingRectangle, "bounds");
            return ((int)(bounds.X + bounds.Width / 2), (int)(bounds.Y + bounds.Height / 2));
        }

        var x = message["x"]?.GetValue<int>() ?? 0;
        var y = message["y"]?.GetValue<int>() ?? 0;
        return (x, y);
    }

    private string Tap((int X, int Y) point, JsonObject message)
    {
        var refId = message["ref"]?.GetValue<string>();
        if (!string.IsNullOrEmpty(refId) && refs.TryGetValue(refId, out var element))
        {
            var byPattern = TryPattern(element, refId);
            if (byPattern != null)
            {
                return byPattern;
            }
        }

        Mouse.Click(new System.Drawing.Point(point.X, point.Y));
        return $"clicked {point.X},{point.Y}";
    }

    /// <summary>Pattern first: the control's own contract, not the mouse position.</summary>
    private static string? TryPattern(AutomationElement element, string refId)
    {
        if (Call(() => element.Patterns.Invoke.IsSupported, "Invoke support"))
        {
            try
            {
                Call(() => element.Patterns.Invoke.Pattern.Invoke(), "Invoke");
                return $"invoked {refId}";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
                // Fall through: the control offered the pattern but did not honour it.
            }
        }

        if (Call(() => element.Patterns.Toggle.IsSupported, "Toggle support"))
        {
            try
            {
                Call(() => element.Patterns.Toggle.Pattern.Toggle(), "Toggle");
                return $"toggled {refId}";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
            }
        }

        if (Call(() => element.Patterns.SelectionItem.IsSupported, "SelectionItem support"))
        {
            try
            {
                Call(() => element.Patterns.SelectionItem.Pattern.Select(), "Select");
                return $"selected {refId}";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
            }
        }

        return null;
    }

    public string? FirstEditableRef()
    {
        foreach (var pair in refs)
        {
            if (Call(() => pair.Value.Patterns.Value.IsSupported, "Value support"))
            {
                return pair.Key;
            }
        }

        return null;
    }

    public string ReadRefValue(string refId)
    {
        if (!refs.TryGetValue(refId, out var element))
        {
            return "";
        }

        try
        {
            return Call(
                () => element.Patterns.Value.IsSupported
                    ? element.Patterns.Value.Pattern.Value.Value ?? ""
                    : "",
                "read value");
        }
        catch
        {
            return "";
        }
    }

    /// <summary>PNG of the foreground window, or null when the screen is not capturable.</summary>
    public byte[]? CaptureWindow()
    {
        try
        {
            var handle = GetForegroundWindow();
            if (!GetWindowRect(handle, out var rect))
            {
                return null;
            }

            var width = rect.Right - rect.Left;
            var height = rect.Bottom - rect.Top;
            if (width <= 0 || height <= 0)
            {
                return null;
            }

            using var bitmap = new System.Drawing.Bitmap(width, height);
            using (var graphics = System.Drawing.Graphics.FromImage(bitmap))
            {
                graphics.CopyFromScreen(rect.Left, rect.Top, 0, 0, bitmap.Size);
            }

            using var stream = new MemoryStream();
            bitmap.Save(stream, System.Drawing.Imaging.ImageFormat.Png);
            return stream.ToArray();
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Accepts an executable path or name, or an Application User Model ID
    /// (AUMID, the Store and packaged-app identity), or shell:AppsFolder\...
    /// </summary>
    private string Launch(string app)
    {
        var start = new ProcessStartInfo { UseShellExecute = true };
        if (app.StartsWith("shell:", StringComparison.OrdinalIgnoreCase))
        {
            start.FileName = "explorer.exe";
            start.Arguments = app;
        }
        else if (app.Contains('!') || app.StartsWith("AUMID:", StringComparison.OrdinalIgnoreCase))
        {
            start.FileName = "explorer.exe";
            start.Arguments = $"shell:AppsFolder\\{app.Replace("AUMID:", "", StringComparison.OrdinalIgnoreCase)}";
        }
        else
        {
            start.FileName = app;
        }

        Process.Start(start);
        var needle = Path.GetFileNameWithoutExtension(app).ToLowerInvariant();
        if (needle.Length == 0 || needle.Contains('!'))
        {
            needle = "";
        }

        // A packaged app (Calculator, Settings) can lose its first activation on
        // a cold start. Wait for the window, then try once more before failing.
        var handle = WaitForWindow(needle, TimeSpan.FromSeconds(12));
        if (handle == IntPtr.Zero)
        {
            Process.Start(start);
            handle = WaitForWindow(needle, TimeSpan.FromSeconds(8));
        }

        if (handle == IntPtr.Zero)
        {
            throw new InvalidOperationException($"launched {app}, but no window appeared within 12 s");
        }

        ForceForeground(handle);
        Thread.Sleep(500);
        if (GetForegroundWindow() != handle)
        {
            AppActivateByHandle(handle);
            Thread.Sleep(600);
        }

        if (GetForegroundWindow() != handle)
        {
            throw new InvalidOperationException(
                $"launched {app}, but could not bring it forward (foreground={ForegroundApp().ToLowerInvariant()})");
        }

        return $"launched {app} (foreground={ForegroundApp().ToLowerInvariant()})";
    }

    private void AppActivateByHandle(IntPtr handle)
    {
        try
        {
            GetWindowThreadProcessId(handle, out var pid);
            var type = System.Type.GetTypeFromProgID("WScript.Shell");
            if (type == null)
            {
                return;
            }

            dynamic shell = Activator.CreateInstance(type)!;
            shell.AppActivate((int)pid);
        }
        catch
        {
            // The caller checks the foreground and reports honestly.
        }
    }

    /// <summary>The Settings app, by its real process. A VS Code window whose
    /// title mentions settings must never be mistaken for it.</summary>
    private IntPtr WaitForSettingsWindow(TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            var handle = FindSettingsWindow();
            if (handle != IntPtr.Zero)
            {
                return handle;
            }

            Thread.Sleep(300);
        }

        return IntPtr.Zero;
    }

    private IntPtr FindSettingsWindow()
    {
        try
        {
            foreach (var window in automation.GetDesktop()
                         .FindAllChildren(cf => cf.ByControlType(ControlType.Window)))
            {
                var process = ProcessNameFor(window);
                var title = Property(() => window.Properties.Name.ValueOrDefault ?? "", "");
                var isSettings = process.Equals("SystemSettings", StringComparison.OrdinalIgnoreCase) ||
                                 (process.Equals("ApplicationFrameHost", StringComparison.OrdinalIgnoreCase) &&
                                  title.Equals("Settings", StringComparison.OrdinalIgnoreCase));
                if (!isSettings)
                {
                    continue;
                }

                var handle = Property(() => window.Properties.NativeWindowHandle.Value, 0);
                if (handle != 0)
                {
                    return (IntPtr)handle;
                }
            }
        }
        catch
        {
            // The desktop enumeration can throw mid-change; the caller retries.
        }

        return IntPtr.Zero;
    }

    /// <summary>An empty needle means "the first real window that appeared after launch".</summary>
    private IntPtr WaitForWindow(string needle, TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        var handle = IntPtr.Zero;
        while (DateTime.UtcNow < deadline && handle == IntPtr.Zero)
        {
            Thread.Sleep(400);
            handle = FindWindowFor(needle);
        }

        return handle;
    }

    private IntPtr FindWindowFor(string needle)
    {
        try
        {
            foreach (var window in automation.GetDesktop().FindAllChildren(cf => cf.ByControlType(ControlType.Window)))
            {
                var title = Property(() => window.Properties.Name.ValueOrDefault ?? "", "").ToLowerInvariant();
                if (title == "program manager" || Property(() => window.Properties.IsOffscreen.ValueOrDefault, true))
                {
                    continue;
                }

                var process = ProcessNameFor(window).ToLowerInvariant();
                if (needle.Length == 0 || process == needle || title.Contains(needle))
                {
                    return (IntPtr)Property(() => window.Properties.NativeWindowHandle.Value, 0);
                }
            }
        }
        catch
        {
            // The desktop enumeration can throw mid-change; the caller says so.
        }

        return IntPtr.Zero;
    }

    private static string ProcessNameFor(AutomationElement element)
    {
        try
        {
            return Process.GetProcessById(element.Properties.ProcessId.Value).ProcessName;
        }
        catch
        {
            return "";
        }
    }

    /// <summary>Windows blocks a background process from stealing focus; attaching
    /// to the thread that currently owns the input queue is the standard way
    /// around it. A bare ALT press first releases the foreground lock, which is
    /// what Windows needs when the caller was started from a terminal.</summary>
    private static void ForceForeground(IntPtr handle)
    {
        ShowWindow(handle, 9);
        if (SetForegroundWindow(handle))
        {
            return;
        }

        UnlockForeground();
        if (SetForegroundWindow(handle))
        {
            return;
        }

        var foreground = GetForegroundWindow();
        var foregroundThread = GetWindowThreadProcessId(foreground, out _);
        var current = GetCurrentThreadId();
        if (foregroundThread != current && AttachThreadInput(current, foregroundThread, true))
        {
            SetForegroundWindow(handle);
            AttachThreadInput(current, foregroundThread, false);
        }
    }

    /// <summary>A down/up of ALT and nothing else: it releases the foreground lock
    /// without typing into the target window.</summary>
    private static void UnlockForeground()
    {
        const byte vkMenu = 0x12;
        const uint keyUp = 0x0002;
        keybd_event(vkMenu, 0, 0, UIntPtr.Zero);
        keybd_event(vkMenu, 0, keyUp, UIntPtr.Zero);
    }

    private string Type(JsonObject message)
    {
        var text = message["text"]?.GetValue<string>() ?? "";
        var refId = message["ref"]?.GetValue<string>();
        if (string.IsNullOrEmpty(refId))
        {
            throw new InvalidOperationException(
                "type needs a ref on Windows; blind typing would hit whatever window is focused");
        }

        if (!refs.TryGetValue(refId, out var element))
        {
            throw new InvalidOperationException($"stale ref {refId}; observe again");
        }

        if (Call(() => element.Patterns.Value.IsSupported, "Value support"))
        {
            try
            {
                Call(() => element.Patterns.Value.Pattern.SetValue(text), "SetValue");
                return $"set {refId} to {text.Length} chars";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
                // Fall through to the keyboard.
            }
        }

        Call(() => element.Focus(), "Focus");
        Keyboard.Type(text);
        return $"typed {text.Length} chars";
    }

    private string Swipe(JsonObject message)
    {
        var fromX = message["fromX"]?.GetValue<int>() ?? 0;
        var fromY = message["fromY"]?.GetValue<int>() ?? 0;
        var toX = message["toX"]?.GetValue<int>() ?? 0;
        var toY = message["toY"]?.GetValue<int>() ?? 0;
        Mouse.MoveTo(new System.Drawing.Point(fromX, fromY));
        Mouse.Down(MouseButton.Left);
        Thread.Sleep(80);
        Mouse.MoveTo(new System.Drawing.Point(toX, toY));
        Mouse.Up(MouseButton.Left);
        return $"swiped {fromX},{fromY} -> {toX},{toY}";
    }

    private string Key(JsonObject message)
    {
        var key = message["key"]?.GetValue<string>() ?? "";
        switch (key)
        {
            case "back":
                Keyboard.Type(VirtualKeyShort.ESC);
                return "pressed Escape (back)";
            case "home":
                Keyboard.Press(VirtualKeyShort.LWIN);
                Keyboard.Type(VirtualKeyShort.KEY_D);
                Keyboard.Release(VirtualKeyShort.LWIN);
                return "showed the desktop (home)";
            default:
                throw new InvalidOperationException($"unknown key {key}");
        }
    }
}

/// <summary>
/// The parts of an observation that must be identical on every run with the same
/// screen: text caps, total text budget and the hash.
/// </summary>
public static class ObservationRules
{
    public const int MaxTextLines = 40;
    public const int MaxTextChars = 200;
    public const int MaxTotalChars = 4000;

    /// <summary>
    /// A window that produced one anonymous node and no text exposes no usable
    /// tree. Saying so is better than handing the loop an empty screen.
    /// </summary>
    public static bool IsTreeOnlyRoot(int nodes, string text) =>
        nodes <= 1 && string.IsNullOrWhiteSpace(text);

    /// <summary>Long labels are cut, not dropped: the hash must not depend on luck.</summary>
    public static string Cap(string text) =>
        text.Length <= MaxTextChars ? text : text[..MaxTextChars] + "\u2026";

    public static string JoinText(IEnumerable<string> lines, out bool truncated)
    {
        var kept = new List<string>();
        var length = 0;
        foreach (var line in lines)
        {
            if (kept.Count == MaxTextLines || length + line.Length > MaxTotalChars)
            {
                truncated = true;
                return string.Join("\n", kept);
            }

            kept.Add(line);
            length += line.Length;
        }

        truncated = false;
        return string.Join("\n", kept);
    }

    public static string Hash(string app, int width, int height, IEnumerable<string> lines)
    {
        var canonical = $"{app}|{width}x{height}|" + string.Join("\n", lines);
        var digest = SHA256.HashData(Encoding.UTF8.GetBytes(canonical));
        return "sha256:" + Convert.ToHexString(digest).ToLowerInvariant();
    }
}
