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
    private void Copy_Click(object sender, RoutedEventArgs e)
    {
        if (lastAnswer.Length > 0)
        {
            Clipboard.SetText(lastAnswer);
            StatusText.Text = "Copied";
        }
    }

    private async void Speak_Click(object sender, RoutedEventArgs e)
    {
        if (lastAnswer.Length == 0)
        {
            return;
        }

        var settings = new SettingsStore().Load();
        var token = CredentialStore.Read("hopa.bridge.token");
        if (settings.BridgeUrl.Length > 0 && token.Length > 0)
        {
            try
            {
                var wav = await voice.SpeakAsync(settings.BridgeUrl, token, lastAnswer);
                if (wav is { Length: > 44 })
                {
                    voice.Play(wav);
                    StatusText.Text = "Reading aloud";
                    return;
                }
            }
            catch (Exception error)
            {
                Log($"voice: {error.Message}");
            }
        }

        speech ??= new SpeechSynthesizer();
        speech.SpeakAsyncCancelAll();
        speech.SpeakAsync(lastAnswer);
        StatusText.Text = "Reading aloud";
    }

    private void Details_Click(object sender, RoutedEventArgs e)
    {
        if (lastSteps == null)
        {
            return;
        }

        var lines = RunStepRow.Lines(lastSteps).ToList();
        if (lines.Count == 0)
        {
            lines.Add("No steps: the answer came without an action.");
        }
        else
        {
            lines.Add($"chain: {(lastChainOk ? "ok" : "failed")}");
        }

        new RunDetailsWindow(lines) { Owner = this }.ShowDialog();
    }
}
