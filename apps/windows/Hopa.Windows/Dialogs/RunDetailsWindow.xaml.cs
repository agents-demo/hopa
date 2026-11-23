using System.Windows;

namespace Hopa.Windows.Dialogs;

public partial class RunDetailsWindow : Window
{
    public RunDetailsWindow(IEnumerable<string> lines)
    {
        InitializeComponent();
        StepsList.ItemsSource = lines;
    }
}
