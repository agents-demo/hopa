using System.Windows;
using System.Windows.Interop;
using Hopa.Windows.Integrations.Device;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>
/// Brings a check window to the real foreground. SetForegroundWindow alone is
/// refused when another process owns the foreground; attaching to its input
/// thread makes the request legal for the duration of the call.
/// </summary>
internal static class DesktopFocus
{
    public static void Bring(Window surface)
    {
        var handle = new WindowInteropHelper(surface).Handle;
        var foreground = Win32.GetForegroundWindow();
        var foregroundThread = foreground == IntPtr.Zero
            ? 0
            : Win32.GetWindowThreadProcessId(foreground, out _);
        var currentThread = Win32.GetCurrentThreadId();
        var attached = foregroundThread != 0 &&
                       foregroundThread != currentThread &&
                       Win32.AttachThreadInput(currentThread, foregroundThread, true);
        try
        {
            Win32.ShowWindow(handle, 5);
            Win32.BringWindowToTop(handle);
            Win32.SetForegroundWindow(handle);
            surface.Activate();
            surface.Focus();
        }
        finally
        {
            if (attached)
            {
                Win32.AttachThreadInput(currentThread, foregroundThread, false);
            }
        }
    }
}
