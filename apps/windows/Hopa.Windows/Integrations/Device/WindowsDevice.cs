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

namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// W3: the Windows device adapter. Observation is a real UI Automation tree with
/// pre-order refs, bounded depth, bounded text and a hash. Actions try the UIA
/// pattern first and fall back to the input stack. Every UIA call has a timeout:
/// a hung provider is reported, never allowed to freeze the turn.
/// </summary>
public sealed partial class WindowsDevice : IDisposable, IDevice
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

    private List<DeviceApp>? appsCache;
    private DateTime appsCachedAt;

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

}
