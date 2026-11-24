using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using Hopa.Windows.Storage;
using Hopa.Windows.Ui;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>
/// P5: pre-fill a real form, pause before the first step, let the person sign,
/// resume, and require the final screen to show the signed label.
///
/// Human mode is the default. `--p5-check <dir> --auto-sign` is an explicit
/// operator stand-in for a recording; the transcript names which one ran.
/// </summary>
internal static class P5Check
{
    public static async Task Run(MainWindow window, string path, bool autoSign)
    {
        Directory.CreateDirectory(path);
        var transcript = Path.Combine(path, "p5-check.txt");
        var mainLog = Path.Combine(path, "p5-main.log");
        var beforePath = Path.Combine(path, "p5-paused.png");
        var signedPath = Path.Combine(path, "p5-signed.png");
        var lines = new List<string>();
        var tools = window.Tools;
        var store = new SettingsStore();
        var settings = store.Load();
        var previousBridge = settings.UseBridge;
        P5FormWindow? form = null;
        try
        {
            if (settings.UseBridge)
            {
                settings.UseBridge = false;
                store.Save(settings);
                lines.Add("target: this PC (the bridge target was restored afterwards)");
            }

            form = new P5FormWindow { Owner = window };
            form.PreFill("Michael");
            form.Show();
            DesktopFocus.Bring(form);
            await Task.Delay(1_200);
            var foreground = tools.Device.ForegroundApp();
            JsonObject observation = new();
            for (var attempt = 0; ; attempt++)
            {
                try
                {
                    (observation, _) = await Task.Run(() => tools.Device.Observe());
                    break;
                }
                catch (Exception error) when (attempt < 4)
                {
                    lines.Add($"observe retry {attempt + 1}: {error.Message}");
                    await Task.Delay(400);
                }
            }

            var screen = observation["text"]?.GetValue<string>() ?? "";
            lines.Add("foreground: " + foreground);
            lines.Add("form visible: " +
                      (screen.Contains("Signature form", StringComparison.Ordinal) &&
                       screen.Contains("Full name", StringComparison.Ordinal)));
            if (!screen.Contains("Signature form", StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    "the signature form did not become foreground; refusing to run the checkpoint");
            }

            tools.SetAutomationOutput(mainLog, "allow");
            await tools.ConnectAsync();
            if (tools.Engine == null)
            {
                throw new InvalidOperationException("the engine did not start");
            }

            lines.Add("prefill: Michael");
            lines.Add("operator: " + (autoSign ? "auto-sign (user-authorised stand-in)" : "human"));
            var goal =
                "The person has signed the P5 form while the turn was paused. " +
                "Do not take any action; confirm that the form is signed.";
            var turn = tools.Engine.StartTurnAsync(
                goal,
                tools.CurrentConversationId,
                checkpoints: new[] { "Signed by Michael" },
                paused: true);
            await Task.Delay(900);
            WindowScreenshot.Save(form, beforePath);
            lines.Add("paused: True");

            if (autoSign)
            {
                form.AutoSign("Michael");
            }
            else
            {
                await form.Signed.WaitAsync(TimeSpan.FromSeconds(300));
            }

            var signed = await form.Signed;
            lines.Add("signed: " + signed);
            WindowScreenshot.Save(form, signedPath);
            tools.Engine.ResumeTurn();
            var result = await turn;
            lines.Add("answer: " + result.Answer);
            lines.Add("checkpoint complete: " + (result.Checkpoints?.Complete == true));
            lines.Add("checkpoint missing: " +
                      string.Join(", ", result.Checkpoints?.Missing ?? Array.Empty<string>()));
            if (result.Checkpoints?.Complete != true)
            {
                throw new InvalidOperationException(
                    "the final screen did not show the signed checkpoint");
            }
        }
        catch (Exception error)
        {
            lines.Add("FAIL: " + error.Message);
        }
        finally
        {
            if (previousBridge)
            {
                var restore = store.Load();
                restore.UseBridge = true;
                store.Save(restore);
            }

            form?.Close();
            tools.WriteLog();
            File.WriteAllLines(transcript, lines);
            tools.Shutdown();
        }
    }

}
