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
using Hopa.Windows.Ui.Chat;
using Hopa.Windows.Checks;
using Hopa.Windows.Ui.Dialogs;
using Hopa.Windows.Integrations.Device;
using Hopa.Windows.Integrations.Engine;
using Hopa.Windows.Integrations.Gateway;
using Hopa.Windows.Storage;
using Hopa.Windows.Integrations.Voice;

namespace Hopa.Windows.Ui.Shell;

public partial class MainWindow : Window
{
    public async Task RunTurnAsync(string goal, string? outPath, string? shotPath, string? approval = null)
    {
        outputPath = outPath;
        autoApproval = approval;
        await ConnectAsync();
        await SendAsync(goal);
        WriteLog();
        if (shotPath != null)
        {
            await Task.Delay(400);
            SaveShot(shotPath);
        }

        Application.Current.Shutdown();
    }

    public async Task ListAsync(string? outPath)
    {
        outputPath = outPath;
        await ConnectAsync();
        foreach (var conversation in conversations)
        {
            Log($"{conversation.Id} | {conversation.Title} | {conversation.MessageCount}");
        }

        WriteLog();
        Application.Current.Shutdown();
    }

    public void SaveShot(string path) => WindowScreenshot.Save(this, path);

    /// <summary>A real screen grab of the window, frame and shadow included.</summary>
    public void FrameShot(string path)
    {
        Activate();
        Thread.Sleep(700);
        var png = device.CaptureWindow();
        if (png == null)
        {
            File.WriteAllText(path + ".error", "no frame");
        }
        else
        {
            File.WriteAllBytes(path, png);
        }

        Application.Current.Shutdown();
    }
}
