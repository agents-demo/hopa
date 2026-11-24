using System.Windows;
using System.Windows.Input;

namespace Hopa.Windows.Ui.Dialogs;

/// <summary>The paused turn: the person works, then resumes or cancels.</summary>
public partial class TakeoverWindow : Window
{
    public TakeoverWindow() => InitializeComponent();

    private void Header_Drag(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }

    private void Resume_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = true;
        Close();
    }
}
