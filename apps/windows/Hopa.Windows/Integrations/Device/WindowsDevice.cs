using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// W3: the Windows device adapter. Observation is a UI Automation tree with
/// pre-order refs, bounded depth, bounded text and a hash. Actions try the UIA
/// pattern first and fall back to the input stack. The tree, input, desktop and
/// app ports keep the rules testable without a real desktop.
/// </summary>
public sealed partial class WindowsDevice : IDisposable, IDevice
{
    private const int MaxNodes = 350;
    private const int MaxDepth = 14;

    private readonly IUiTree tree;
    private readonly IInput input;
    private readonly IDesktopSession desktop;
    private readonly IAppCatalog apps;
    private readonly IAppLauncher launcher;
    private readonly Dictionary<string, IUiNode> refs = new();
    private IUiNode? root;
    private int counter;
    private int textChars;

    public WindowsDevice()
    {
        desktop = new WindowsDesktopSession();
        tree = new FlaUiTree();
        input = new WindowsInput();
        apps = new WindowsAppCatalog();
        launcher = new WindowsAppLauncher(tree, desktop, input);
    }

    internal WindowsDevice(
        IUiTree tree,
        IInput input,
        IDesktopSession desktop,
        IAppCatalog apps,
        IAppLauncher launcher)
    {
        this.tree = tree;
        this.input = input;
        this.desktop = desktop;
        this.apps = apps;
        this.launcher = launcher;
    }

    /// <summary>
    /// The refusal the current foreground would produce, or null when it is
    /// usable. Cheap and read-only: it checks the process, never UI Automation,
    /// so a wait loop can poll it while the session locks.
    /// </summary>
    public string? UnreadableReason() => desktop.UnreadableReason();

    public string ForegroundApp() => desktop.ForegroundApp();

    public System.Windows.Size ScreenSize() => desktop.ScreenSize();

    public string Act(string op, JsonObject message)
    {
        Refuse();
        var point = PointFor(message);
        switch (op)
        {
            case "tap":
                return Tap(point, message);
            case "doubleTap":
                input.DoubleClick(point.X, point.Y);
                return $"double-clicked {point.X},{point.Y}";
            case "longPress":
                input.MoveTo(point.X, point.Y);
                input.MouseDown();
                Thread.Sleep(700);
                input.MouseUp();
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

                return launcher.Launch(app);
            case "stop":
                var target = message["app"]?.GetValue<string>() ?? "";
                if (target.Length == 0)
                {
                    throw new InvalidOperationException("stop needs an app");
                }

                return launcher.Stop(target);
            default:
                throw new InvalidOperationException($"the Windows adapter cannot '{op}' yet");
        }
    }

    public List<DeviceApp> Apps() => apps.Apps();

    /// <summary>PNG of the foreground window, or null when the screen is not capturable.</summary>
    public byte[]? CaptureWindow() => desktop.CaptureWindow();

    public void Dispose() => tree.Dispose();

    private void Refuse()
    {
        if (desktop.UnreadableReason() is { } reason)
        {
            throw new InvalidOperationException(reason);
        }
    }
}
