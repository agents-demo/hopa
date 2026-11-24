using FlaUI.UIA3;

namespace Hopa.Windows.Integrations.Device;

/// <summary>The UI Automation session, opened once per device adapter.</summary>
internal sealed class FlaUiTree : IUiTree
{
    private readonly UIA3Automation automation = new();

    public IUiNode? Foreground()
    {
        try
        {
            var hwnd = Win32.GetForegroundWindow();
            return hwnd == IntPtr.Zero ? null : new FlaUiNode(automation.FromHandle(hwnd));
        }
        catch
        {
            return null;
        }
    }

    public IUiNode Desktop() => new FlaUiNode(automation.GetDesktop());

    public void Dispose() => automation.Dispose();
}
