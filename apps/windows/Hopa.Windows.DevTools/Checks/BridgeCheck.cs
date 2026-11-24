using System.IO;
using Hopa.Windows.Storage;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>Points the app at a bridge URL and token, then runs one turn through it.</summary>
internal static class BridgeCheck
{
    public static async Task Run(MainWindow window, string url, string token, string path)
    {
        var settings = new SettingsStore();
        var current = settings.Load();
        current.BridgeUrl = url;
        current.UseBridge = true;
        settings.Save(current);
        CredentialStore.Write("hopa.bridge.token", token);

        var tools = window.Tools;
        tools.SetAutomationOutput(path, "allow");
        await tools.ConnectAsync();
        await tools.SendAsync("open settings on the phone");
        tools.WriteLog();
        tools.Shutdown();
    }
}
