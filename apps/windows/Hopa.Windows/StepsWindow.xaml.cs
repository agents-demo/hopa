using System.Windows;

namespace Hopa.Windows;

public partial class StepsWindow : Window
{
    public StepsWindow(IEnumerable<string> lines)
    {
        InitializeComponent();
        StepsList.ItemsSource = lines;
    }
}
