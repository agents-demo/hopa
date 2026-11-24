using System.IO;
using System.Windows;

namespace Hopa.Windows.Ui.Shell;

/// <summary>
/// The product's two scripted modes. They drive the real window but add no
/// developer checks; everything else lives in Hopa.Windows.DevTools.
/// </summary>
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
            Hopa.Windows.Ui.WindowScreenshot.Save(this, shotPath);
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
}
