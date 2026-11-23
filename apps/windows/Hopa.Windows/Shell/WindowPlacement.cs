using System.Windows;
using Hopa.Windows.Storage;

namespace Hopa.Windows.Shell;

/// <summary>The window's size and position, remembered across restarts.</summary>
internal static class WindowPlacement
{
    public static void Restore(Window window)
    {
        var settings = new SettingsStore().Load();
        if (settings.WindowWidth >= 800 && settings.WindowHeight >= 500)
        {
            window.Width = settings.WindowWidth;
            window.Height = settings.WindowHeight;
        }

        if (settings.WindowLeft is { } left && settings.WindowTop is { } top)
        {
            window.Left = left;
            window.Top = top;
            if (!IsOnAnyScreen(new Rect(left, top, window.Width, window.Height)))
            {
                // The monitor that held the window is gone or was rearranged.
                window.WindowStartupLocation = WindowStartupLocation.CenterScreen;
                window.Left = double.NaN;
                window.Top = double.NaN;
            }
        }

        if (settings.WindowMaximized)
        {
            window.WindowState = WindowState.Maximized;
        }
    }

    public static void Save(Window window)
    {
        var store = new SettingsStore();
        var current = store.Load();
        var bounds = window.WindowState == WindowState.Normal
            ? new Rect(window.Left, window.Top, window.Width, window.Height)
            : window.RestoreBounds;
        current.WindowLeft = bounds.Left;
        current.WindowTop = bounds.Top;
        current.WindowWidth = bounds.Width;
        current.WindowHeight = bounds.Height;
        current.WindowMaximized = window.WindowState == WindowState.Maximized;
        store.Save(current);
    }

    /// <summary>A saved position is only useful if that part of the desktop still exists.</summary>
    public static bool IsOnAnyScreen(Rect bounds)
    {
        var virtualScreen = new Rect(
            SystemParameters.VirtualScreenLeft,
            SystemParameters.VirtualScreenTop,
            SystemParameters.VirtualScreenWidth,
            SystemParameters.VirtualScreenHeight);
        var overlap = Rect.Intersect(bounds, virtualScreen);
        return !overlap.IsEmpty && overlap.Width > 80 && overlap.Height > 40;
    }
}
