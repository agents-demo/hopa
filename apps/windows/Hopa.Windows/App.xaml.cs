using System.Windows;
using Hopa.Windows.Cli;
using Hopa.Windows.Shell;

namespace Hopa.Windows;

/// <summary>The composition root: a command line picks a mode, otherwise the shell opens.</summary>
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        var command = CommandLine.Parse(e.Args);
        if (command == null)
        {
            new MainWindow().Show();
            return;
        }

        RunModes.Run(command, this);
    }
}
