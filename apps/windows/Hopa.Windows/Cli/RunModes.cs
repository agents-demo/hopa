using System.Windows;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.Cli;

/// <summary>The two script modes the product keeps: a headless turn and a conversation list.</summary>
internal static class RunModes
{
    public static void Run(Command command, Application app)
    {
        var window = new MainWindow();
        window.Show();
        switch (command.Mode)
        {
            case RunMode.Turn:
                _ = window.RunTurnAsync(
                    command.Arg(0),
                    command.ArgOrNull(1),
                    command.ArgOrNull(2),
                    command.ArgOrNull(3));
                break;
            case RunMode.ConversationList:
                _ = window.ListAsync(command.ArgOrNull(0));
                break;
            default:
                app.Shutdown();
                break;
        }
    }
}
