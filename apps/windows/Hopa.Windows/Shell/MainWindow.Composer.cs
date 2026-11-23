using System.Collections.ObjectModel;
using System.IO;
using System.Net.Http;
using System.Speech.Synthesis;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using System.Windows.Shell;
using Hopa.Windows.Chat;
using Hopa.Windows.Checks;
using Hopa.Windows.Dialogs;
using Hopa.Windows.Device;
using Hopa.Windows.Engine;
using Hopa.Windows.Gateway;
using Hopa.Windows.Storage;
using Hopa.Windows.Voice;

namespace Hopa.Windows.Shell;

public partial class MainWindow : Window
{
    private void Composer_TextChanged(object sender, TextChangedEventArgs e) =>
        ComposerPlaceholder.Visibility = Composer.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;

    private async void TargetChip_Click(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        var store = new SettingsStore();
        var settings = store.Load();
        settings.UseBridge = !settings.UseBridge;
        store.Save(settings);
        UpdateBridgeStatus();
        await ApplySettingsAsync();
    }

    private async void Window_Drop(object sender, DragEventArgs e)
    {
        if (client == null || !e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            return;
        }

        if (e.Data.GetData(DataFormats.FileDrop) is not string[] files || files.Length == 0)
        {
            return;
        }

        try
        {
            var attachment = await client.AttachFileAsync(files[0]);
            pendingAttachment = attachment;
            PendingAttachmentName.Text = attachment["name"]?.GetValue<string>() ?? "file";
            var bytes = attachment["bytes"]?.GetValue<long>() ?? 0;
            PendingAttachmentDetail.Text =
                $"{HumanSize(bytes)} \u00B7 {attachment["mime"]?.GetValue<string>()}";
            PendingAttachmentBar.Visibility = Visibility.Visible;
            StatusText.Text = "File ready to send";
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
        }
    }

    private async void RemoveAttachment_Click(object sender, RoutedEventArgs e)
    {
        var path = pendingAttachment?["path"]?.GetValue<string>();
        pendingAttachment = null;
        PendingAttachmentBar.Visibility = Visibility.Collapsed;
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

    private async void Mic_Click(object sender, RoutedEventArgs e)
    {
        if (voice.Recording)
        {
            var wav = voice.StopCapture();
            MicButton.Content = "Mic";
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
            MicButton.Content = "Stop";
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

            Composer.Text = Composer.Text.Length == 0 ? text : $"{Composer.Text} {text}";
            Composer.CaretIndex = Composer.Text.Length;
            StatusText.Text = "";
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
            Log($"voice: {error.Message}");
        }
    }
}
