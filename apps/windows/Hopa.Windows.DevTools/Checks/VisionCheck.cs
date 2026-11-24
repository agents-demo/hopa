using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Hopa.Windows.Integrations.Device;
using Hopa.Windows.Storage;
using Hopa.Windows.Ui;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>
/// W10 vision: a code is drawn only in the frame, never in the UI Automation
/// tree. If the model answers the code, it saw the screenshot; if it cannot,
/// the transcript says so instead of claiming a round-trip.
/// </summary>
internal static class VisionCheck
{
    public static async Task Run(MainWindow window, string path)
    {
        Directory.CreateDirectory(path);
        var transcript = Path.Combine(path, "vision-check.txt");
        var framePath = Path.Combine(path, "vision-nonce.png");
        var screenPath = Path.Combine(path, "vision-screen.png");
        var mainLog = Path.Combine(path, "vision-main.log");
        var lines = new List<string>();
        Window? surface = null;
        var tools = window.Tools;
        var store = new SettingsStore();
        var settings = store.Load();
        var previousBridge = settings.UseBridge;
        try
        {
            lines.Add($"model: {settings.ModelName}");
            lines.Add($"vision setting: {settings.Vision}");
            if (!settings.Vision)
            {
                throw new InvalidOperationException(
                    "Vision is off in settings; enable Settings > Answers > Vision first");
            }

            // The frame must come from this PC, not from a phone reached by the
            // bridge; the check restores the person's target afterwards.
            if (settings.UseBridge)
            {
                settings.UseBridge = false;
                store.Save(settings);
                lines.Add("target: this PC (the bridge target was restored afterwards)");
            }

            var word = Word();
            var frame = Render(word);
            Save(frame, framePath);
            surface = Show(frame);
            ForceForeground(surface);
            await Task.Delay(700);
            var foreground = tools.Device.ForegroundApp();
            lines.Add("foreground: " + foreground);
            if (!foreground.Equals("Hopa.Windows.DevTools", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    $"the vision window did not become foreground (foreground is '{foreground}')");
            }

            var direct = tools.Device.CaptureWindow();
            lines.Add("device frame: " + (direct == null ? "null" : $"{direct.Length} bytes"));

            tools.SetAutomationOutput(mainLog, "allow");
            await tools.ConnectAsync();
            if (tools.Engine == null)
            {
                throw new InvalidOperationException("the engine did not start");
            }

            lines.Add($"word: {word}");
            var goal =
                "The attached screenshot shows one word rendered as an image. " +
                "Read the word and reply with the word only. Do not guess.";
            var result = await tools.Engine.StartTurnAsync(goal, tools.CurrentConversationId);
            var answer = result.Answer.Trim();
            lines.Add($"answer: {answer}");
            lines.Add("match: " + (answer.Contains(word, StringComparison.OrdinalIgnoreCase)
                ? "True"
                : "False"));
            WindowScreenshot.Save(surface, screenPath);
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

            surface?.Close();
            tools.WriteLog();
            File.WriteAllLines(transcript, lines);
            tools.Shutdown();
        }
    }

    private static string Word()
    {
        string[] words =
        {
            "BANANA", "ORCHID", "RIVER", "PLANET", "SILVER",
            "GARDEN", "ROCKET", "MEADOW", "COPPER", "ISLAND",
            "VIOLET", "FALCON", "CANYON", "MARBLE", "ORANGE",
            "WINTER", "SUMMER", "PENCIL", "GUITAR", "MARKET",
        };
        return words[Random.Shared.Next(words.Length)];
    }

    private static RenderTargetBitmap Render(string word)
    {
        var visual = new DrawingVisual();
        using (var context = visual.RenderOpen())
        {
            context.DrawRectangle(Brushes.White, null, new Rect(0, 0, 760, 260));
            var text = new FormattedText(
                word,
                CultureInfo.InvariantCulture,
                FlowDirection.LeftToRight,
                new Typeface(
                    new FontFamily("Consolas"),
                    FontStyles.Normal,
                    FontWeights.Bold,
                    FontStretches.Normal),
                110,
                Brushes.Black,
                1.0);
            context.DrawText(text, new Point(40, 55));
        }

        var bitmap = new RenderTargetBitmap(760, 260, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(visual);
        return bitmap;
    }

    private static Window Show(ImageSource frame)
    {
        var surface = new Window
        {
            Title = "HOPA vision check",
            Width = 800,
            Height = 320,
            WindowStyle = WindowStyle.None,
            ResizeMode = ResizeMode.NoResize,
            WindowStartupLocation = WindowStartupLocation.CenterScreen,
            Topmost = true,
            ShowInTaskbar = false,
            Background = Brushes.White,
            Content = new Border
            {
                Background = Brushes.White,
                Child = new Image
                {
                    Source = frame,
                    Stretch = Stretch.None,
                },
            },
        };
        surface.Show();
        surface.Activate();
        return surface;
    }

    private static void ForceForeground(Window surface)
    {
        var handle = new WindowInteropHelper(surface).Handle;
        Win32.ShowWindow(handle, 5);
        Win32.SetForegroundWindow(handle);
        surface.Activate();
        surface.Focus();
    }

    private static void Save(BitmapSource bitmap, string path)
    {
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(path);
        encoder.Save(stream);
    }
}
