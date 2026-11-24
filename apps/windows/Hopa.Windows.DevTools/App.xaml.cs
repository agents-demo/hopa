using System.Windows;
using Hopa.Windows.Cli;
using Hopa.Windows.DevTools.Cli;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools;

/// <summary>The developer exe: the same window plus every check and screenshot mode.</summary>
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

        DevRunModes.Run(command, this);
    }
}
