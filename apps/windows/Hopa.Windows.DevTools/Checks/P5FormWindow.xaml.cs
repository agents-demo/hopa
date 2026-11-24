using System.Windows;
using System.Windows.Input;
using System.Windows.Media;

namespace Hopa.Windows.DevTools.Checks;

/// <summary>
/// The P5 form: HOPA pre-fills the name, the person signs while the turn is
/// paused, and Submit makes the signed label visible for the checkpoint.
/// </summary>
public partial class P5FormWindow : Window
{
    private readonly TaskCompletionSource<string> signed =
        new(TaskCreationOptions.RunContinuationsAsynchronously);

    public P5FormWindow()
    {
        InitializeComponent();
        FullNameBox.Text = "Michael";
        Loaded += (_, _) =>
        {
            SignatureBox.Focus();
            Keyboard.Focus(SignatureBox);
        };
    }

    public Task<string> Signed => signed.Task;

    public void AutoSign(string signature)
    {
        SignatureBox.Text = signature;
        Submit();
    }

    public void PreFill(string fullName) => FullNameBox.Text = fullName;

    private void Submit_Click(object sender, RoutedEventArgs e) => Submit();

    private void Submit()
    {
        var name = FullNameBox.Text.Trim();
        var signature = SignatureBox.Text.Trim();
        if (name.Length == 0 || signature.Length == 0)
        {
            ResultText.Text = "Full name and signature are both required.";
            ResultText.Foreground = Brushes.Firebrick;
            return;
        }

        ResultText.Text = $"Signed by {name}";
        ResultText.Foreground = new SolidColorBrush(Color.FromRgb(10, 89, 247));
        signed.TrySetResult(ResultText.Text);
    }

    private void Header_Drag(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }
}
