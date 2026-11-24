using System.IO;
using System.Windows;
using System.Windows.Input;
using Hopa.Windows.Ui;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Shots;

/// <summary>
/// W4 close-out: the desktop behaviours that need a window but not a sidecar.
/// Writes a transcript and one screenshot; every line is a claim the reader
/// can check in the UI.
/// </summary>
internal static class WindowCheck
{
    public static void Run(MainWindow window, string directory)
    {
        Directory.CreateDirectory(directory);
        var lines = new List<string>();
        try
        {
            Body(window, directory, lines);
        }
        catch (Exception error)
        {
            lines.Add($"error: {error.GetType().Name}: {error.Message}");
        }

        File.WriteAllLines(Path.Combine(directory, "w4-check.txt"), lines);
        window.Tools.Shutdown();
    }

    private static void Body(MainWindow window, string directory, List<string> lines)
    {
        var tools = window.Tools;
        var tray = tools.Tray;
        lines.AddRange(new[]
        {
            $"tray icon created: {tray != null}",
            $"tray Stop disabled before a turn: {tray?.StopEnabled == false}",
            $"tray tooltip: '{tray?.Tooltip}'",
            $"high contrast active: {SystemParameters.HighContrast}",
            "shortcuts: Ctrl+N new chat; Ctrl+F or Ctrl+K search; Enter send; Shift+Enter newline; Esc stop",
            $"window bounds: {window.Left:0},{window.Top:0} {window.Width:0}x{window.Height:0}",
            $"window on a screen: {WindowPlacement.IsOnAnyScreen(new Rect(window.Left, window.Top, window.Width, window.Height))}",
            $"off-screen restore refused: {!WindowPlacement.IsOnAnyScreen(new Rect(-9000, -9000, window.Width, window.Height))}",
            $"automation names on controls: {CountNames(window)}",
            $"focusable controls: {CountFocusable(window)}",
            $"tab navigation: {KeyboardNavigation.GetTabNavigation(window)}",
        });

        if (tray != null)
        {
            lines.Add("toast: shown through the tray balloon");
            window.Dispatcher.BeginInvoke(new Action(() =>
                tray.ShowBalloon("HOPA", "W4 check: notification while the window is unfocused")));
        }
        else
        {
            lines.Add("toast: no tray icon");
        }

        var shot = Path.Combine(directory, "windows-w4.png");
        WindowScreenshot.Save(window, shot);
        lines.Add($"screenshot: {shot}");
    }

    private static int CountFocusable(DependencyObject root)
    {
        var count = root is FrameworkElement element && element.Focusable && element.IsVisible ? 1 : 0;
        var children = System.Windows.Media.VisualTreeHelper.GetChildrenCount(root);
        for (var index = 0; index < children; index++)
        {
            count += CountFocusable(System.Windows.Media.VisualTreeHelper.GetChild(root, index));
        }

        return count;
    }

    private static int CountNames(DependencyObject root)
    {
        var count = System.Windows.Automation.AutomationProperties.GetName(root).Length > 0 ? 1 : 0;
        var children = System.Windows.Media.VisualTreeHelper.GetChildrenCount(root);
        for (var index = 0; index < children; index++)
        {
            count += CountNames(System.Windows.Media.VisualTreeHelper.GetChild(root, index));
        }

        return count;
    }
}
