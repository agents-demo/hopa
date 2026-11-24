using System.Windows;
using Hopa.Windows.Storage;

namespace Hopa.Windows.Ui.Shell;

/// <summary>
/// Applies the shell profile chosen on Android's profiles screen: Easy, Kid and
/// Social hide the run rail, Everyday and Power keep it.
/// </summary>
public partial class MainWindow
{
    internal void ApplyProfile()
    {
        var profile = new SettingsStore().Load().Profile;
        var showRail = profile is not ("easy" or "kid" or "social");
        Rail.Visibility = showRail ? Visibility.Visible : Visibility.Collapsed;
    }
}
