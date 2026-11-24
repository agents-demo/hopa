using System.IO;
using System.Windows;

namespace Hopa.Windows.Ui.Shell;

/// <summary>The tray icon: its menu, the working state and the balloon.</summary>
internal sealed class TrayIcon : IDisposable
{
    private readonly System.Windows.Forms.NotifyIcon icon;
    private readonly System.Windows.Forms.ToolStripItem stop;
    private readonly System.Drawing.Icon iconImage;

    public TrayIcon(Window window, Action stopTurn, Action exit)
    {
        iconImage = AppIcon();
        icon = new System.Windows.Forms.NotifyIcon
        {
            Icon = iconImage,
            Text = "HOPA",
            Visible = true,
        };
        var menu = new System.Windows.Forms.ContextMenuStrip();
        menu.Items.Add("Open", null, (_, _) => Show(window));
        stop = menu.Items.Add("Stop", null, (_, _) => stopTurn());
        stop.Enabled = false;
        menu.Items.Add("Exit", null, (_, _) => exit());
        icon.ContextMenuStrip = menu;
        icon.DoubleClick += (_, _) => Show(window);
    }

    public bool StopEnabled
    {
        get => stop.Enabled;
        set => stop.Enabled = value;
    }

    public string Tooltip
    {
        get => icon.Text ?? "";
        set => icon.Text = value;
    }

    /// <summary>The same mascot the window and the executable use.</summary>
    public static System.Drawing.Icon AppIcon()
    {
        var resource = Application.GetResourceStream(
            new Uri("pack://application:,,,/Hopa.Windows;component/Assets/hopa.ico", UriKind.Absolute))
            ?? throw new InvalidOperationException("the HOPA icon resource is missing");
        using var stream = resource.Stream;
        return new System.Drawing.Icon(stream);
    }

    public void ShowBalloon(string title, string text) =>
        icon.ShowBalloonTip(
            4000,
            title,
            text,
            System.Windows.Forms.ToolTipIcon.Info);

    private static void Show(Window window)
    {
        window.Show();
        if (window.WindowState == WindowState.Minimized)
        {
            window.WindowState = WindowState.Normal;
        }

        window.Activate();
    }

    public void Dispose()
    {
        icon.Dispose();
        iconImage.Dispose();
    }
}
