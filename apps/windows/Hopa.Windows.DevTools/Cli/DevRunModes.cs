using System.Windows;
using Hopa.Windows.Checks;
using Hopa.Windows.Cli;
using Hopa.Windows.DevTools.Checks;
using Hopa.Windows.DevTools.Shots;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Cli;

/// <summary>
/// Runs one developer command line. Windowless checks run before the shell
/// exists; the rest open the real window through the harness.
/// </summary>
internal static class DevRunModes
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
                _ = SettingsShot.Run(window, command.Arg(0));
                break;
            case RunMode.DraftCheck:
                _ = DraftCheck.Run(window, command.Arg(0));
                break;
            case RunMode.BridgeCheck:
                _ = BridgeCheck.Run(window, command.Arg(0), command.Arg(1), command.Arg(2));
                break;
            case RunMode.ChatShot:
                window.Dispatcher.BeginInvoke(new Action(() => ChatShot.Run(window, command.Arg(0))));
                break;
            case RunMode.KeyboardCheck:
                window.Dispatcher.BeginInvoke(new Action(() => KeyboardCheck.Run(window, command.Arg(0))));
                break;
            case RunMode.ComponentShot:
                window.Dispatcher.BeginInvoke(new Action(() => ComponentShot.Run(window, command.Arg(0))));
                break;
            case RunMode.FrameShot:
                window.Dispatcher.BeginInvoke(new Action(() => FrameShot.Run(window, command.Arg(0))));
                break;
            case RunMode.WindowCheck:
                window.Dispatcher.BeginInvoke(new Action(() => WindowCheck.Run(window, command.Arg(0))));
                break;
            case RunMode.AttachCheck:
                _ = AttachCheck.Run(window, command.Arg(0), command.Arg(1));
                break;
            case RunMode.CancelCheck:
                _ = CancelCheck.Run(window, command.Arg(0));
                break;
            case RunMode.HistoryCheck:
                _ = HistoryCheck.Run(window, command.Arg(0));
                break;
            case RunMode.PcCheck:
                _ = PcCheck.Run(window, command.Arg(0));
                break;
            case RunMode.Pair:
                _ = PairCheck.Run(window, command.Arg(0), command.Arg(1), command.Arg(2));
                break;
            case RunMode.StaleCheck:
                _ = StaleCheck.Run(window, command.Arg(0), command.Arg(1));
                break;
            default:
                app.Shutdown();
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
