using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Hopa.Windows;

public partial class MainWindow : Window
{
    private readonly List<string> log = new();
    private SidecarClient? client;
    private string? outputPath;
    private bool running;

    public MainWindow()
    {
        InitializeComponent();
        Loaded += async (_, _) => await ConnectAsync();
    }

    public async Task RunTurnAsync(string goal, string? outPath, string? shotPath = null)
    {
        outputPath = outPath;
        await ConnectAsync();
        await SendTurnAsync(goal);
        WriteLog();
        if (shotPath != null)
        {
            await Task.Delay(400);
            SaveShot(shotPath);
        }

        Application.Current.Shutdown();
    }

    public void SaveShot(string path)
    {
        UpdateLayout();
        var width = (int)Math.Max(ActualWidth, 1);
        var height = (int)Math.Max(ActualHeight, 1);
        var bitmap = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(this);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(path);
        encoder.Save(stream);
    }

    private async Task ConnectAsync()
    {
        if (client != null)
        {
            return;
        }

        try
        {
            var started = new SidecarClient();
            started.LogReceived += line => Log($"sidecar: {line}");
            started.DeviceRequested += OnDeviceRequested;
            client = started;
            StatusText.Text = "Sidecar ready. Try \"say hello\" or \"click the notepad text area\".";
        }
        catch (Exception error)
        {
            StatusText.Text = $"The sidecar did not start: {error.Message}";
            Log($"error: {error.Message}");
        }

        await Task.CompletedTask;
    }

    private async void SendButton_Click(object sender, RoutedEventArgs e)
    {
        await SendFromBoxAsync();
    }

    private async void GoalBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            await SendFromBoxAsync();
        }
    }

    private async Task SendFromBoxAsync()
    {
        var goal = GoalBox.Text.Trim();
        if (goal.Length == 0)
        {
            return;
        }

        GoalBox.Clear();
        await SendTurnAsync(goal);
    }

    private async Task SendTurnAsync(string goal)
    {
        if (client == null || running)
        {
            return;
        }

        running = true;
        SendButton.IsEnabled = false;
        Log($"you: {goal}");
        StatusText.Text = "Working...";
        try
        {
            var answer = await client.StartTurnAsync(goal);
            Log($"HOPA: {answer}");
            StatusText.Text = "Done.";
        }
        catch (Exception error)
        {
            Log($"error: {error.Message}");
            StatusText.Text = error.Message;
        }
        finally
        {
            running = false;
            SendButton.IsEnabled = true;
            WriteLog();
        }
    }

    private void OnDeviceRequested(JsonObject message)
    {
        var id = message["id"]?.GetValue<string>() ?? "";
        var op = message["op"]?.GetValue<string>() ?? "";
        if (client == null)
        {
            return;
        }

        try
        {
            if (op == "tap")
            {
                var result = NotepadClicker.ClickTextArea();
                Log($"device: {result}");
                client.SendDeviceResult(id, true);
                return;
            }

            var reason = $"the W0 host cannot do '{op}' yet";
            Log($"device: {reason}");
            client.SendDeviceResult(id, false, reason);
        }
        catch (Exception error)
        {
            Log($"device error: {error.Message}");
            client.SendDeviceResult(id, false, error.Message);
        }
    }

    private void Log(string line)
    {
        Dispatcher.Invoke(() =>
        {
            log.Add(line);
            OutputBox.AppendText(line + Environment.NewLine);
            OutputBox.ScrollToEnd();
        });
    }

    private void WriteLog()
    {
        if (outputPath == null)
        {
            return;
        }

        File.WriteAllLines(outputPath, log);
    }
}
