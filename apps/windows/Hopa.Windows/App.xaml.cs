using System.Windows;

namespace Hopa.Windows;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        var args = e.Args;

        // Headless checks that need no window. They run before the shell exists
        // so they also work on a locked or otherwise non-interactive desktop.
        if (args.Length >= 2 && args[0] == "--w3-check")
        {
            W3Check.Run(args[1]);
            Shutdown();
            return;
        }

        if (args.Length >= 2 && args[0] == "--p2-check")
        {
            P2Check.Run(args[1]);
            Shutdown();
            return;
        }

        if (args.Length >= 2 && args[0] == "--p2-wait")
        {
            var seconds = args.Length >= 3 && int.TryParse(args[2], out var parsed) ? parsed : 12;
            var mode = args.Length >= 4 ? args[3] : "lock";
            P2Check.RunWait(args[1], seconds, mode);
            Shutdown();
            return;
        }

        if (args.Length >= 2 && args[0] == "--p3-check")
        {
            P3Check.Run(args[1]);
            Shutdown();
            return;
        }

        if (args.Length >= 2 && args[0] == "--p3-check")
        {
            P3Check.Run(args[1]);
            Shutdown();
            return;
        }

        var window = new MainWindow();
        window.Show();
        if (args.Length >= 2 && args[0] == "--turn")
        {
            string? output = null;
            string? shot = null;
            string? approval = null;
            for (var i = 2; i + 1 < args.Length; i += 2)
            {
                switch (args[i])
                {
                    case "--out":
                        output = args[i + 1];
                        break;
                    case "--shot":
                        shot = args[i + 1];
                        break;
                    case "--approval":
                        approval = args[i + 1];
                        break;
                }
            }

            _ = window.RunTurnAsync(args[1], output, shot, approval);
            return;
        }

        if (args.Length >= 1 && args[0] == "--list")
        {
            string? output = args.Length >= 3 && args[1] == "--out" ? args[2] : null;
            _ = window.ListAsync(output);
            return;
        }

        if (args.Length >= 2 && args[0] == "--shot-settings")
        {
            _ = window.ShotSettingsAsync(args[1]);
            return;
        }

        if (args.Length >= 2 && args[0] == "--settings-check")
        {
            _ = window.SettingsCheckAsync(args[1]);
            return;
        }

        if (args.Length >= 2 && args[0] == "--draft-check")
        {
            _ = window.DraftCheckAsync(args[1]);
            return;
        }

        if (args.Length >= 4 && args[0] == "--bridge-check")
        {
            _ = window.BridgeCheckAsync(args[1], args[2], args[3]);
            return;
        }

        if (args.Length >= 2 && args[0] == "--shot-chat")
        {
            window.Dispatcher.BeginInvoke(new Action(() => window.ShotChat(args[1])));
            return;
        }

        if (args.Length >= 2 && args[0] == "--keyboard-check")
        {
            window.Dispatcher.BeginInvoke(new Action(() => window.KeyboardCheck(args[1])));
            return;
        }

        if (args.Length >= 2 && args[0] == "--shot-components")
        {
            window.Dispatcher.BeginInvoke(new Action(() => window.ShotComponents(args[1])));
            return;
        }

        if (args.Length >= 2 && args[0] == "--shot-frame")
        {
            window.Dispatcher.BeginInvoke(new Action(() => window.FrameShot(args[1])));
            return;
        }

        if (args.Length >= 2 && args[0] == "--w4-check")
        {
            window.Dispatcher.BeginInvoke(new Action(() => window.W4Check(args[1])));
            return;
        }

        if (args.Length >= 2 && args[0] == "--matrix-check")
        {
            _ = window.MatrixCheckAsync(args[1]);
            return;
        }

        if (args.Length >= 3 && args[0] == "--attach-check")
        {
            _ = window.AttachCheckAsync(args[1], args[2]);
            return;
        }

        if (args.Length >= 2 && args[0] == "--cancel-check")
        {
            _ = window.CancelCheckAsync(args[1]);
            return;
        }

        if (args.Length >= 3 && args[0] == "--voice-check")
        {
            _ = window.VoiceCheckAsync(args[1], args[2]);
            return;
        }

        if (args.Length >= 2 && args[0] == "--history-check")
        {
            _ = window.HistoryCheckAsync(args[1]);
            return;
        }

        if (args.Length >= 2 && args[0] == "--pc-check")
        {
            _ = window.PcCheckAsync(args[1]);
            return;
        }

        if (args.Length >= 4 && args[0] == "--pair")
        {
            _ = window.PairAsync(args[1], args[2], args[3]);
            return;
        }

        if (args.Length >= 3 && args[0] == "--stale-check")
        {
            _ = window.StaleCheckAsync(args[1], args[2]);
        }
    }
}
