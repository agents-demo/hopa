using System.Windows;
using Hopa.Windows.Cli;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows;

/// <summary>The composition root: a product script mode, otherwise the shell opens.</summary>
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        var command = CommandLine.Parse(e.Args);
        if (command is { Mode: RunMode.Turn or RunMode.ConversationList })
        {
            RunModes.Run(command, this);
            return;
        }

        // Developer checks live in Hopa.Windows.DevTools; this exe only ships
        // the window and the two script modes above.
        new MainWindow().Show();
    }
}
