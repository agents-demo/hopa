using System.Windows;

namespace Hopa.Windows;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        var window = new MainWindow();
        if (e.Args.Length >= 2 && e.Args[0] == "--turn")
        {
            string? output = null;
            string? shot = null;
            for (var i = 2; i + 1 < e.Args.Length; i += 2)
            {
                switch (e.Args[i])
                {
                    case "--out":
                        output = e.Args[i + 1];
                        break;
                    case "--shot":
                        shot = e.Args[i + 1];
                        break;
                }
            }

            window.Show();
            _ = window.RunTurnAsync(e.Args[1], output, shot);
            return;
        }

        window.Show();
    }
}
