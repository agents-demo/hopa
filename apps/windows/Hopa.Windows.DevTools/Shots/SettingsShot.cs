using Hopa.Windows.Ui;
using Hopa.Windows.Ui.Dialogs;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Shots;

/// <summary>Opens the settings dialog through the real connection and saves it.</summary>
internal static class SettingsShot
{
    public static async Task Run(MainWindow window, string path)
    {
        var tools = window.Tools;
        await tools.ConnectAsync();
        var dialog = new SettingsWindow(window.Tools.Engine) { Owner = window };
        dialog.Show();
        await Task.Delay(600);
        WindowScreenshot.Save(dialog, path);
        dialog.Close();
        tools.Shutdown();
    }
}
