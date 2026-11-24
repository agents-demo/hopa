using System.IO;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Shots;

/// <summary>A real screen grab of the window, frame and shadow included.</summary>
internal static class FrameShot
{
    public static void Run(MainWindow window, string path)
    {
        window.Activate();
        Thread.Sleep(700);
        var png = window.Tools.CaptureWindow();
        if (png == null)
        {
            File.WriteAllText(path + ".error", "no frame");
        }
        else
        {
            File.WriteAllBytes(path, png);
        }

        window.Tools.Shutdown();
    }
}
