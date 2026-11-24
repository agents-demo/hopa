using System.IO;
using Hopa.Windows.Storage;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>Rotates the refresh token, keeps the stale access token and checks the host recovers.</summary>
internal static class StaleCheck
{
    public static async Task Run(MainWindow window, string url, string path)
    {
        var staleToken = CredentialStore.Read("hopa.bridge.token");
        var refresh = CredentialStore.Read("hopa.bridge.refresh");
        var (ok, newToken, newRefresh) = await BridgePost.PostAsync(url, "/refresh", new { refresh });
        // Keep the old token (now rejected) and hand the sidecar the rotated refresh.
        CredentialStore.Write("hopa.bridge.refresh", newRefresh);

        var tools = window.Tools;
        tools.SetAutomationOutput(path, "allow");
        await tools.ConnectAsync();
        await tools.SendAsync("open settings on the phone");
        tools.Log($"stale check: rotation={(ok && newToken.Length > 0 ? "ok" : "FAIL")} " +
                  $"token_changed={newToken != staleToken}");
        tools.WriteLog();
        tools.Shutdown();
    }
}
