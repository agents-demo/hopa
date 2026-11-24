using System.Collections.ObjectModel;
using System.Text.Json.Nodes;
using System.Windows;
using Hopa.Windows.Integrations.Device;
using Hopa.Windows.Integrations.Engine;
using Hopa.Windows.Ui.Chat;
using Hopa.Windows.Ui.Panes;

namespace Hopa.Windows.Ui.Shell;

/// <summary>
/// The narrow surface the separate DevTools exe uses to drive the real window.
/// It exposes operations, not checks, so the product assembly stays free of
/// developer gates.
/// </summary>
public partial class MainWindow
{
    internal Harness Tools => new(this);

    internal sealed class Harness
    {
        private readonly MainWindow window;

        internal Harness(MainWindow window) => this.window = window;

        internal MainWindow Window => window;

        internal ChatView Chat => window.Chat;

        internal RunRailView Rail => window.Rail;

        internal TrayIcon? Tray => window.tray;

        internal WindowsDevice Device => window.device;

        internal EngineHostClient? Engine => window.client;

        internal string? CurrentConversationId => window.chatController?.CurrentId;

        internal ObservableCollection<ConversationRow> Conversations => window.conversations;

        internal string ComposerText
        {
            get => window.Chat.Model.ComposerText;
            set => window.Chat.Model.ComposerText = value;
        }

        internal void ClearStatus() => window.StatusText.Text = "";

        internal void SetPendingAttachment(JsonObject? attachment) =>
            window.pendingAttachment = attachment;

        internal void SetAutomationOutput(string? outputPath, string? autoApproval)
        {
            window.outputPath = outputPath;
            window.autoApproval = autoApproval;
        }

        internal Task ConnectAsync() => window.ConnectAsync();

        internal Task SendAsync(string goal) => window.SendAsync(goal);

        internal Task SelectAsync(string id) => window.SelectAsync(id);

        internal void Log(string line) => window.Log(line);

        internal void WriteLog() => window.WriteLog();

        internal byte[]? CaptureWindow() => window.device.CaptureWindow();

        internal void Shutdown() => Application.Current.Shutdown();
    }
}
