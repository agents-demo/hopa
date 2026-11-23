using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using Hopa.Windows.Chat;
using Hopa.Windows.Dialogs;
using Hopa.Windows.Storage;

namespace Hopa.Windows.Shell;

public partial class MainWindow : Window
{
    private void CopyAnswer()
    {
        if (Chat.Model.LastAnswer.Length == 0)
        {
            return;
        }

        Clipboard.SetText(Chat.Model.LastAnswer);
        StatusText.Text = "Copied";
    }

    private async Task SpeakAnswerAsync()
    {
        var answer = Chat.Model.LastAnswer;
        if (answer.Length == 0)
        {
            return;
        }

        var settings = new SettingsStore().Load();
        var token = CredentialStore.Read("hopa.bridge.token");
        if (settings.BridgeUrl.Length > 0 && token.Length > 0)
        {
            try
            {
                var wav = await voice.SpeakAsync(settings.BridgeUrl, token, answer);
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

        speech ??= new System.Speech.Synthesis.SpeechSynthesizer();
        speech.SpeakAsyncCancelAll();
        speech.SpeakAsync(answer);
        StatusText.Text = "Reading aloud";
    }

    private void ShowRunDetails()
    {
        if (Chat.Model.LastSteps == null)
        {
            return;
        }

        var lines = RunStepRow.Lines(Chat.Model.LastSteps).ToList();
        if (lines.Count == 0)
        {
            lines.Add("No steps: the answer came without an action.");
        }
        else
        {
            lines.Add($"chain: {(Chat.Model.LastChainOk ? "ok" : "failed")}");
        }

        new RunDetailsWindow(lines) { Owner = this }.ShowDialog();
    }
}
