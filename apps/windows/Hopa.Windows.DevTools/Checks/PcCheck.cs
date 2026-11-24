using Hopa.Windows.Storage;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>Runs the local-device path with the bridge off: open Notepad and type into it.</summary>
internal static class PcCheck
{
    public static async Task Run(MainWindow window, string path)
    {
        var settings = new SettingsStore();
        var current = settings.Load();
        current.UseBridge = false;
        settings.Save(current);

        var tools = window.Tools;
        tools.SetAutomationOutput(path, "allow");
        await tools.ConnectAsync();
        await tools.SendAsync("open notepad");
        await tools.SendAsync("type hello in notepad");
        tools.WriteLog();
        tools.Shutdown();
    }
}
