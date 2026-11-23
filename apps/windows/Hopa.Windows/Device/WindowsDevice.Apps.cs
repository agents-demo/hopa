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

namespace Hopa.Windows.Device;

/// <summary>
/// W3: the Windows device adapter. Observation is a real UI Automation tree with
/// pre-order refs, bounded depth, bounded text and a hash. Actions try the UIA
/// pattern first and fall back to the input stack. Every UIA call has a timeout:
/// a hung provider is reported, never allowed to freeze the turn.
/// </summary>
public sealed partial class WindowsDevice
{
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
}
