using System.IO;
using Hopa.Windows.Storage;

namespace Hopa.Windows.Checks;

/// <summary>Settings round-trip and a secret round-trip through Credential Manager.</summary>
public static class SettingsCheck
{
    public static string Run(string path)
    {
        var storePath = Path.Combine(Path.GetTempPath(), $"hopa-settings-{Guid.NewGuid():N}.json");
        var store = new SettingsStore(storePath);
        try
        {
            var probe = new AppSettings
            {
                BridgeUrl = "http://127.0.0.1:8901",
                UseBridge = true,
                ModelProvider = "lan",
                ModelBaseUrl = "http://127.0.0.1:11434/v1",
                Tone = "neutral",
            };
            store.Save(probe);
            var loaded = store.Load();
            var settingsOk = loaded.BridgeUrl == probe.BridgeUrl
                && loaded.UseBridge
                && loaded.ModelProvider == "lan"
                && loaded.Tone == "neutral";

            CredentialStore.Write("hopa.test.secret", "s3cret");
            var secretOk = CredentialStore.Read("hopa.test.secret") == "s3cret";
            CredentialStore.Delete("hopa.test.secret");
            var gone = CredentialStore.Read("hopa.test.secret").Length == 0;

            var lines = new[]
            {
                $"settings round-trip: {(settingsOk ? "ok" : "FAIL")}",
                $"credential round-trip: {(secretOk ? "ok" : "FAIL")}",
                $"credential delete: {(gone ? "ok" : "FAIL")}",
                $"settings file: {store.FilePath}",
            };
            File.WriteAllLines(path, lines);
            return string.Join(Environment.NewLine, lines);
        }
        finally
        {
            if (File.Exists(storePath))
            {
                File.Delete(storePath);
            }
        }
    }
}
