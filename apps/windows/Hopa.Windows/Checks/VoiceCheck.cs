using System.IO;
using Hopa.Windows.Storage;
using Hopa.Windows.Integrations.Voice;

namespace Hopa.Windows.Checks;

/// <summary>
/// The bridge speech round-trip: `/speak` returns audio, `/transcribe` reads it
/// back. It needs the bridge but not a microphone.
/// </summary>
public static class VoiceCheck
{
    public static async Task<string> Run(string url, string path)
    {
        var token = CredentialStore.Read("hopa.bridge.token");
        var lines = new List<string>();
        using var voice = new VoiceClient();
        try
        {
            var wav = await voice.SpeakAsync(url, token, "hello from hopa");
            lines.Add($"speak: {(wav is { Length: > 44 } ? "ok" : "FAIL")} ({wav?.Length ?? 0} bytes)");
            if (wav != null)
            {
                var text = await voice.TranscribeAsync(url, token, wav);
                lines.Add($"transcribe: '{text}'");
                lines.Add($"round-trip: {(text.Length > 0 ? "ok" : "FAIL")}");
            }
        }
        catch (Exception error)
        {
            lines.Add($"error: {error.Message}");
        }

        File.WriteAllLines(path, lines);
        return string.Join(Environment.NewLine, lines);
    }
}
