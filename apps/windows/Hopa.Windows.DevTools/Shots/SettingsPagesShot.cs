using Hopa.Windows.Ui.Dialogs;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Shots;

/// <summary>W11: one screenshot per settings page, for the parity artifact.</summary>
internal static class SettingsPagesShot
{
    public static async Task Run(MainWindow window, string directory)
    {
        var tools = window.Tools;
        await tools.ConnectAsync();
        var dialog = new SettingsWindow(tools.Engine, tools.Device) { Owner = window };
        dialog.Show();
        dialog.UpdateLayout();
        await Task.Delay(600);
        dialog.CapturePages(directory);
        dialog.Close();
        tools.Shutdown();
    }
}
