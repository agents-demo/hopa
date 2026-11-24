using System.Diagnostics;
using System.IO;

namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// The real desktop: lock and elevation rules, the foreground process, screen
/// size and scale, and a window screenshot.
/// </summary>
internal sealed class WindowsDesktopSession : IDesktopSession
{
    private static readonly string[] SecureProcesses =
    {
        "lockapp", "logonui", "winlogon", "screensaver",
    };

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

    public string ForegroundApp()
    {
        var hwnd = Win32.GetForegroundWindow();
        Win32.GetWindowThreadProcessId(hwnd, out var pid);
        try
        {
            return Process.GetProcessById((int)pid).ProcessName;
        }
        catch
        {
            return "";
        }
    }

    public System.Windows.Size ScreenSize()
    {
        var width = (int)System.Windows.SystemParameters.PrimaryScreenWidth;
        var height = (int)System.Windows.SystemParameters.PrimaryScreenHeight;
        return new System.Windows.Size(width, height);
    }

    public double Dpi()
    {
        var hwnd = Win32.GetForegroundWindow();
        return hwnd == IntPtr.Zero ? 96 : Math.Max(96, Win32.GetDpiForWindow(hwnd));
    }

    /// <summary>PNG of the foreground window, or null when the screen is not capturable.</summary>
    public byte[]? CaptureWindow()
    {
        try
        {
            var handle = Win32.GetForegroundWindow();
            if (!Win32.GetWindowRect(handle, out var rect))
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

    /// <summary>The lock screen and the logon desktop refuse input by design.</summary>
    private static bool IsSecureSurface(out string processName)
    {
        processName = "";
        var hwnd = Win32.GetForegroundWindow();
        if (hwnd == IntPtr.Zero)
        {
            return true;
        }

        var thread = Win32.GetWindowThreadProcessId(hwnd, out var pid);
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

    private static void RefuseSecureSurface()
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
    private static void RefuseElevatedBoundary()
    {
        var hwnd = Win32.GetForegroundWindow();
        if (hwnd == IntPtr.Zero)
        {
            return;
        }

        Win32.GetWindowThreadProcessId(hwnd, out var pid);
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

        var process = Win32.OpenProcess(queryLimited, false, (uint)pid);
        if (process == IntPtr.Zero)
        {
            return null;
        }

        try
        {
            if (!Win32.OpenProcessToken(process, tokenQuery, out var token))
            {
                return null;
            }

            try
            {
                return Win32.GetTokenInformation(token, tokenElevation, out var info, sizeof(int), out _)
                    ? info != 0
                    : null;
            }
            finally
            {
                Win32.CloseHandle(token);
            }
        }
        finally
        {
            Win32.CloseHandle(process);
        }
    }
}
