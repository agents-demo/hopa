using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;

namespace Hopa.Windows.Panes;

/// <summary>The conversation control. It renders the model and raises the actions the window owns.</summary>
public partial class ChatView : UserControl
{
    public ChatView()
    {
        InitializeComponent();
        DataContext = Model;
    }

    public ChatViewModel Model { get; } = new();

    public event Action? SendRequested;

    public event Action? MicRequested;

    public event Action? CopyRequested;

    public event Action? SpeakRequested;

    public event Action? DetailsRequested;

    public event Action? AttachmentRemoveRequested;

    public event Action? TargetChipRequested;

    public event Action<string>? FileDropped;

    public void ScrollToEnd() =>
        Dispatcher.BeginInvoke(new Action(() => MessagesScroll.ScrollToEnd()));

    private void Send_Click(object sender, RoutedEventArgs e) => SendRequested?.Invoke();

    private void Mic_Click(object sender, RoutedEventArgs e) => MicRequested?.Invoke();

    private void Copy_Click(object sender, RoutedEventArgs e) => CopyRequested?.Invoke();

    private void Speak_Click(object sender, RoutedEventArgs e) => SpeakRequested?.Invoke();

    private void Details_Click(object sender, RoutedEventArgs e) => DetailsRequested?.Invoke();

    private void RemoveAttachment_Click(object sender, RoutedEventArgs e) =>
        AttachmentRemoveRequested?.Invoke();

    private void TargetChip_Click(object sender, MouseButtonEventArgs e) =>
        TargetChipRequested?.Invoke();

    private void Composer_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter && (Keyboard.Modifiers & ModifierKeys.Shift) == 0)
        {
            e.Handled = true;
            SendRequested?.Invoke();
        }
    }

    private void View_Drop(object sender, DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(DataFormats.FileDrop) ||
            e.Data.GetData(DataFormats.FileDrop) is not string[] files ||
            files.Length == 0)
        {
            return;
        }

        FileDropped?.Invoke(files[0]);
    }
}
