using System.Windows;
using Hopa.Windows.Checks;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.Cli;

/// <summary>
/// Runs one command line. Checks that need no window run before the shell exists,
/// so they also work on a locked or otherwise non-interactive desktop. Everything
/// else opens the real window and drives it.
/// </summary>
internal static class RunModes
{
    public static void Run(Command command, Application app)
    {
        switch (command.Mode)
        {
            case RunMode.ObservationCheck:
                ObservationCheck.Run(command.Arg(0));
                app.Shutdown();
                return;
            case RunMode.DevicePortCheck:
                DevicePortCheck.Run(command.Arg(0));
                app.Shutdown();
                return;
            case RunMode.DevicePortWait:
                DevicePortCheck.RunWait(
                    command.Arg(0),
                    command.Int(1, 12),
                    command.ArgOr(2, "lock"));
                app.Shutdown();
                return;
            case RunMode.IntentCheck:
                IntentCheck.Run(command.Arg(0));
                app.Shutdown();
                return;
            case RunMode.AppMatrixCheck:
                Finish(AppMatrixCheck.Run(command.Arg(0)), app);
                return;
            case RunMode.VoiceCheck:
                Finish(VoiceCheck.Run(command.Arg(0), command.Arg(1)), app);
                return;
            case RunMode.SettingsCheck:
                SettingsCheck.Run(command.Arg(0));
                app.Shutdown();
                return;
        }

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
            case RunMode.SettingsShot:
                _ = window.ShotSettingsAsync(command.Arg(0));
                break;
            case RunMode.DraftCheck:
                _ = window.DraftCheckAsync(command.Arg(0));
                break;
            case RunMode.BridgeCheck:
                _ = window.BridgeCheckAsync(command.Arg(0), command.Arg(1), command.Arg(2));
                break;
            case RunMode.ChatShot:
                window.Dispatcher.BeginInvoke(new Action(() => window.ShotChat(command.Arg(0))));
                break;
            case RunMode.KeyboardCheck:
                window.Dispatcher.BeginInvoke(new Action(() => window.KeyboardCheck(command.Arg(0))));
                break;
            case RunMode.ComponentShot:
                window.Dispatcher.BeginInvoke(new Action(() => window.ShotComponents(command.Arg(0))));
                break;
            case RunMode.FrameShot:
                window.Dispatcher.BeginInvoke(new Action(() => window.FrameShot(command.Arg(0))));
                break;
            case RunMode.WindowCheck:
                window.Dispatcher.BeginInvoke(new Action(() => window.W4Check(command.Arg(0))));
                break;
            case RunMode.AttachCheck:
                _ = window.AttachCheckAsync(command.Arg(0), command.Arg(1));
                break;
            case RunMode.CancelCheck:
                _ = window.CancelCheckAsync(command.Arg(0));
                break;
            case RunMode.HistoryCheck:
                _ = window.HistoryCheckAsync(command.Arg(0));
                break;
            case RunMode.PcCheck:
                _ = window.PcCheckAsync(command.Arg(0));
                break;
            case RunMode.Pair:
                _ = window.PairAsync(command.Arg(0), command.Arg(1), command.Arg(2));
                break;
            case RunMode.StaleCheck:
                _ = window.StaleCheckAsync(command.Arg(0), command.Arg(1));
                break;
        }
    }

    private static async void Finish(Task task, Application app)
    {
        try
        {
            await task;
        }
        finally
        {
            app.Shutdown();
        }
    }
}
