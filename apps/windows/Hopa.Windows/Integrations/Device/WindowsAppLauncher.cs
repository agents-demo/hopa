using System.Diagnostics;
using System.IO;

namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// The shell side of the device: open a link, start an app, close an app, and
/// bring its window forward. Windows rules about focus belong here, not in the
/// observation code.
/// </summary>
internal sealed class WindowsAppLauncher : IAppLauncher
{
    private readonly IUiTree tree;
    private readonly IDesktopSession desktop;
    private readonly IInput input;

    public WindowsAppLauncher(IUiTree tree, IDesktopSession desktop, IInput input)
    {
        this.tree = tree;
        this.desktop = desktop;
        this.input = input;
    }

    public string OpenLink(string url)
    {
        var scheme = Uri.TryCreate(url, UriKind.Absolute, out var uri)
            ? uri.Scheme.ToLowerInvariant()
            : "";
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

        return $"opened {url} (foreground={desktop.ForegroundApp()})";
    }

    public string Launch(string app)
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
        if (Win32.GetForegroundWindow() != handle)
        {
            AppActivateByHandle(handle);
            Thread.Sleep(600);
        }

        if (Win32.GetForegroundWindow() != handle)
        {
            throw new InvalidOperationException(
                $"launched {app}, but could not bring it forward (foreground={desktop.ForegroundApp().ToLowerInvariant()})");
        }

        return $"launched {app} (foreground={desktop.ForegroundApp().ToLowerInvariant()})";
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
            foreach (var window in DesktopWindows())
            {
                var process = ProcessNameFor(window);
                var title = UiCalls.Property(() => window.Name, "");
                var isSettings = process.Equals("SystemSettings", StringComparison.OrdinalIgnoreCase) ||
                                 (process.Equals("ApplicationFrameHost", StringComparison.OrdinalIgnoreCase) &&
                                  title.Equals("Settings", StringComparison.OrdinalIgnoreCase));
                if (!isSettings)
                {
                    continue;
                }

                var handle = UiCalls.Property(() => window.NativeWindowHandle, IntPtr.Zero);
                if (handle != IntPtr.Zero)
                {
                    return handle;
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
            foreach (var window in DesktopWindows())
            {
                var title = UiCalls.Property(() => window.Name, "").ToLowerInvariant();
                if (title == "program manager" || UiCalls.Property(() => window.IsOffscreen, true))
                {
                    continue;
                }

                var process = ProcessNameFor(window).ToLowerInvariant();
                if (needle.Length == 0 || process == needle || title.Contains(needle))
                {
                    return UiCalls.Property(() => window.NativeWindowHandle, IntPtr.Zero);
                }
            }
        }
        catch
        {
            // The desktop enumeration can throw mid-change; the caller says so.
        }

        return IntPtr.Zero;
    }

    private IEnumerable<IUiNode> DesktopWindows() =>
        UiCalls.Call(() => tree.Desktop().Children(), "desktop windows")
            .Where(window => UiCalls.Property(() => window.ControlType, "") == "Window");

    private static string ProcessNameFor(IUiNode element)
    {
        try
        {
            return Process.GetProcessById(element.ProcessId).ProcessName;
        }
        catch
        {
            return "";
        }
    }

    private void AppActivateByHandle(IntPtr handle)
    {
        try
        {
            Win32.GetWindowThreadProcessId(handle, out var pid);
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

    /// <summary>Windows blocks a background process from stealing focus; attaching
    /// to the thread that currently owns the input queue is the standard way
    /// around it. A bare ALT press first releases the foreground lock, which is
    /// what Windows needs when the caller was started from a terminal.</summary>
    private void ForceForeground(IntPtr handle)
    {
        Win32.ShowWindow(handle, 9);
        if (Win32.SetForegroundWindow(handle))
        {
            return;
        }

        input.ReleaseForegroundLock();
        if (Win32.SetForegroundWindow(handle))
        {
            return;
        }

        var foreground = Win32.GetForegroundWindow();
        var foregroundThread = Win32.GetWindowThreadProcessId(foreground, out _);
        var current = Win32.GetCurrentThreadId();
        if (foregroundThread != current && Win32.AttachThreadInput(current, foregroundThread, true))
        {
            Win32.SetForegroundWindow(handle);
            Win32.AttachThreadInput(current, foregroundThread, false);
        }
    }
}
