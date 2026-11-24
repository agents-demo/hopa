using System.Windows;
using Hopa.Windows.Ui.Dialogs;

namespace Hopa.Windows.Ui.Shell;

/// <summary>Pause a running turn, let the person work, then resume or cancel.</summary>
public partial class MainWindow
{
    private void Takeover_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || chatController?.Running != true)
        {
            return;
        }

        client.PauseTurn();
        StatusText.Text = "Paused for takeover";
        var resume = new TakeoverWindow { Owner = this }.ShowDialog() == true;
        if (resume)
        {
            client.ResumeTurn();
            StatusText.Text = "Working...";
        }
        else
        {
            client.CancelTurn();
            StatusText.Text = "Stopping...";
        }
    }
}
