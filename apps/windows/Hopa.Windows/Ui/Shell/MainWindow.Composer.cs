using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using Hopa.Windows.Storage;

namespace Hopa.Windows.Ui.Shell;

public partial class MainWindow : Window
{
    /// <summary>The target chip toggles between the phone and this laptop.</summary>
    private async Task ToggleTargetAsync()
    {
        var store = new SettingsStore();
        var settings = store.Load();
        settings.UseBridge = !settings.UseBridge;
        store.Save(settings);
        UpdateBridgeStatus();
        await ApplySettingsAsync();
    }

    /// <summary>A file dropped on the conversation is attached through the engine.</summary>
    private async Task AttachAsync(string path)
    {
        if (client == null)
        {
            return;
        }

        try
        {
            var attachment = await client.AttachFileAsync(path);
            pendingAttachment = attachment;
            var name = attachment["name"]?.GetValue<string>() ?? "file";
            var bytes = attachment["bytes"]?.GetValue<long>() ?? 0;
            var mime = attachment["mime"]?.GetValue<string>() ?? "";
            Chat.Model.ShowAttachment(name, $"{HumanSize(bytes)} \u00B7 {mime}");
            StatusText.Text = "File ready to send";
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
        }
    }

    private async void RemoveAttachment()
    {
        var path = pendingAttachment?["path"]?.GetValue<string>();
        pendingAttachment = null;
        Chat.Model.ClearAttachment();
        if (path != null && client != null)
        {
            try
            {
                await client.RequestAsync("file.remove", new JsonObject { ["path"] = path },
                    TimeSpan.FromSeconds(10));
            }
            catch (Exception error)
            {
                Log($"attachment: {error.Message}");
            }
        }
    }

    private static string HumanSize(long bytes) => bytes switch
    {
        >= 1024 * 1024 => $"{bytes / (1024.0 * 1024.0):0.0} MB",
        >= 1024 => $"{bytes / 1024} KB",
        _ => $"{bytes} B",
    };

    private static string Describe(JsonObject attachment)
    {
        var name = attachment["name"]?.GetValue<string>() ?? "file";
        var mime = attachment["mime"]?.GetValue<string>() ?? "";
        return mime.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
            ? $"Shared an image: {name}"
            : $"Shared a file: {name}";
    }

    /// <summary>One microphone button: start capture, or stop and transcribe.</summary>
    private async Task MicAsync()
    {
        if (voice.Recording)
        {
            var wav = voice.StopCapture();
            Chat.Model.SetMic(recording: false);
            StatusText.Text = "";
            if (wav.Length <= 44)
            {
                StatusText.Text = "Nothing recorded.";
                return;
            }

            await TranscribeAsync(wav);
            return;
        }

        try
        {
            voice.StartCapture();
            Chat.Model.SetMic(recording: true);
            StatusText.Text = "Listening...";
        }
        catch (Exception error)
        {
            StatusText.Text = $"No microphone: {error.Message}";
        }
    }

    private async Task TranscribeAsync(byte[] wav)
    {
        var settings = new SettingsStore().Load();
        var token = CredentialStore.Read("hopa.bridge.token");
        if (settings.BridgeUrl.Length == 0 || token.Length == 0)
        {
            StatusText.Text = "Dictation needs the bridge. Set its address and token in Settings.";
            return;
        }

        StatusText.Text = "Transcribing...";
        try
        {
            var text = await voice.TranscribeAsync(settings.BridgeUrl, token, wav);
            if (text.Length == 0)
            {
                StatusText.Text = "I did not catch that.";
                return;
            }

            Chat.Model.AppendComposer(text);
            StatusText.Text = "";
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
            Log($"voice: {error.Message}");
        }
    }
}
