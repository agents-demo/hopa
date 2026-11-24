using System.IO;
using Hopa.Windows.Storage;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>Pairs this PC with a bridge code and stores the token and refresh.</summary>
internal static class PairCheck
{
    public static async Task Run(MainWindow window, string url, string code, string path)
    {
        var (ok, token, refresh) = await BridgePost.PostAsync(url, "/pair", new { code });
        if (ok && token.Length > 0)
        {
            CredentialStore.Write("hopa.bridge.token", token);
            CredentialStore.Write("hopa.bridge.refresh", refresh);
            var settings = new SettingsStore();
            var current = settings.Load();
            current.BridgeUrl = url;
            current.UseBridge = true;
            settings.Save(current);
        }

        File.WriteAllLines(path, new[]
        {
            $"pair: {(ok && token.Length > 0 ? "ok" : "FAIL")}",
            $"refresh stored: {refresh.Length > 0}",
        });
        window.Tools.Shutdown();
    }
}
