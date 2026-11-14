using System.Windows;

namespace Hopa.Windows;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        var window = new MainWindow();
        window.Show();
        var args = e.Args;
        if (args.Length >= 2 && args[0] == "--turn")
        {
            string? output = null;
            string? shot = null;
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
                }
            }

            _ = window.RunTurnAsync(args[1], output, shot);
            return;
        }

        if (args.Length >= 1 && args[0] == "--list")
        {
            string? output = args.Length >= 3 && args[1] == "--out" ? args[2] : null;
            _ = window.ListAsync(output);
        }
    }
}
