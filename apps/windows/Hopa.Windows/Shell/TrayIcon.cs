using System.Windows;

namespace Hopa.Windows.Shell;

/// <summary>The tray icon: its menu, the working state and the balloon.</summary>
internal sealed class TrayIcon : IDisposable
{
    private readonly System.Windows.Forms.NotifyIcon icon;
    private readonly System.Windows.Forms.ToolStripItem stop;

    public TrayIcon(Window window, Action stopTurn, Action exit)
    {
        icon = new System.Windows.Forms.NotifyIcon
        {
            Icon = LaptopIcon(),
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

    /// <summary>The laptop mark, drawn once at 32 px for the tray and the taskbar.</summary>
    public static System.Drawing.Icon LaptopIcon()
    {
        var bitmap = new System.Drawing.Bitmap(32, 32);
        using (var g = System.Drawing.Graphics.FromImage(bitmap))
        {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.Clear(System.Drawing.Color.Transparent);
            var orange = new System.Drawing.SolidBrush(System.Drawing.Color.FromArgb(0xE8, 0x70, 0x3A));
            var cream = new System.Drawing.SolidBrush(System.Drawing.Color.FromArgb(0xFF, 0xFD, 0xF7));
            var ink = new System.Drawing.SolidBrush(System.Drawing.Color.FromArgb(0x1C, 0x1B, 0x18));
            g.FillRectangle(orange, 5, 6, 22, 16);
            g.FillRectangle(orange, 25, 10, 3, 5);
            g.FillRectangle(cream, 8, 9, 16, 10);
            g.FillEllipse(ink, 11, 12, 2, 2);
            g.FillEllipse(ink, 17, 12, 2, 2);
            g.DrawArc(new System.Drawing.Pen(ink, 1.6f), 12, 14, 8, 4, 20, 140);
            g.FillRectangle(orange, 2, 23, 28, 4);
            g.FillRectangle(cream, 14, 24, 4, 1);
        }

        var handle = bitmap.GetHicon();
        return System.Drawing.Icon.FromHandle(handle);
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

    public void Dispose() => icon.Dispose();
}
