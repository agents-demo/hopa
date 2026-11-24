using System.Collections.ObjectModel;
using System.IO;
using System.Net.Http;
using System.Speech.Synthesis;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using System.Windows.Shell;
using Hopa.Windows.Ui.Chat;
using Hopa.Windows.Ui.Dialogs;
using Hopa.Windows.Integrations.Device;
using Hopa.Windows.Integrations.Engine;
using Hopa.Windows.Integrations.Gateway;
using Hopa.Windows.Storage;
using Hopa.Windows.Integrations.Voice;
using Hopa.Windows.Host;

namespace Hopa.Windows.Ui.Shell;

public partial class MainWindow : Window
{
    private ObservableCollection<ConversationRow> conversations => Sidebar.Model.Visible;
    private List<ConversationRow> allConversations => Sidebar.Model.All;
    private ObservableCollection<MessageBubble> messages => Chat.Model.Messages;
    private readonly List<string> log = new();
    private readonly WindowsDevice device = new();
    private readonly VoiceClient voice = new();
    private SpeechSynthesizer? speech;
    private TrayIcon? tray;
    private EngineHostClient? client;
    private ChatController? chatController;
    private EngineSession? session;
    private Task? connecting;
    private JsonObject? pendingAttachment;
    private string? autoApproval;
    private string? outputPath;

    public MainWindow()
    {
        InitializeComponent();
        // The Harmony laptop app hides the system decoration and keeps its own
        // window controls. WindowChrome does the same here: the top 52 px drags,
        // the three buttons stay clickable, the resize border remains.
        WindowChrome.SetWindowChrome(this, new WindowChrome
        {
            CaptionHeight = 52,
            ResizeBorderThickness = new Thickness(6),
            GlassFrameThickness = new Thickness(0),
            CornerRadius = new CornerRadius(0),
            UseAeroCaptionButtons = false,
        });
        foreach (var button in new[] { MinimizeButton, MaximizeButton, CloseButton })
        {
            WindowChrome.SetIsHitTestVisibleInChrome(button, true);
        }

        StateChanged += (_, _) => MaximizeButton.Content = WindowState == WindowState.Maximized
            ? "\u2750"
            : "\u25A1";
        Sidebar.ExportRequested += row => _ = ExportAsync(row);
        Sidebar.NewChatRequested += () => _ = NewChatAsync();
        Sidebar.SettingsRequested += () => _ = OpenSettingsAsync();
        Sidebar.BridgeHintRequested += () => _ = OpenSettingsAsync();
        Sidebar.IncludeArchivedChanged += () => _ = ReloadConversationsAsync();
        Sidebar.SelectionChanged += row => _ = SelectAsync(row.Id);
        Sidebar.PinRequested += row => _ = PinAsync(row);
        Sidebar.ArchiveRequested += row => _ = ArchiveAsync(row);
        Sidebar.RenameRequested += row => _ = RenameAsync(row);
        Sidebar.DeleteRequested += row => _ = DeleteAsync(row);
        Chat.SendRequested += () => _ = SendFromComposerAsync();
        Chat.MicRequested += () => _ = MicAsync();
        Chat.CopyRequested += CopyAnswer;
        Chat.SpeakRequested += () => _ = SpeakAnswerAsync();
        Chat.DetailsRequested += ShowRunDetails;
        Chat.AttachmentRemoveRequested += RemoveAttachment;
        Chat.FileDropped += path => _ = AttachAsync(path);
        Chat.TargetChipRequested += () => _ = ToggleTargetAsync();
        tray = new TrayIcon(this, () => client?.CancelTurn(), () => Close());

        SourceInitialized += (_, _) => RoundCorners();
        Loaded += (_, _) => WindowPlacement.Restore(this);
        Closing += (_, _) => WindowPlacement.Save(this);
        Closed += (_, _) =>
        {
            tray?.Dispose();
            speech?.Dispose();
            voice.Dispose();
            device.Dispose();
            _ = session?.DisposeAsync();
        };
        Loaded += async (_, _) => await ConnectAsync();
    }

    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    /// <summary>Win11 draws the rounded frame; Win10 ignores the attribute.</summary>
    private void RoundCorners()
    {
        var handle = new System.Windows.Interop.WindowInteropHelper(this).Handle;
        var round = 2;
        DwmSetWindowAttribute(handle, 33, ref round, sizeof(int));
    }

    private void Minimize_Click(object sender, RoutedEventArgs e)
    {
        SystemCommands.MinimizeWindow(this);
    }

    private void Maximize_Click(object sender, RoutedEventArgs e)
    {
        if (WindowState == WindowState.Maximized)
        {
            SystemCommands.RestoreWindow(this);
        }
        else
        {
            SystemCommands.MaximizeWindow(this);
        }
    }

    private void Close_Click(object sender, RoutedEventArgs e)
    {
        SystemCommands.CloseWindow(this);
    }

    private void Log(string line)
    {
        lock (log)
        {
            log.Add(line);
        }
    }

    private void WriteLog()
    {
        if (outputPath == null)
        {
            return;
        }

        lock (log)
        {
            File.WriteAllLines(outputPath, log);
        }
    }

}
