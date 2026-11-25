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

namespace Hopa.Windows.Ui.Shell;

public partial class MainWindow : Window
{



    private async Task RefreshAsync()
    {
        if (chatController == null)
        {
            return;
        }

        var id = await chatController.LoadAsync(
            Sidebar.Model.IncludeArchived,
            createIfEmpty: true);
        if (id != null)
        {
            await SelectAsync(id);
        }
    }

    private async Task SelectAsync(string id)
    {
        if (chatController == null)
        {
            return;
        }

        var title = await chatController.SelectAsync(id);
        if (title == null)
        {
            return;
        }

        TitleText.Text = title;
        Sidebar.Select(conversations.FirstOrDefault(item => item.Id == id)
            ?? allConversations.FirstOrDefault(item => item.Id == id));
        Chat.ScrollToEnd();
        StatusText.Text = "";
    }

    private async Task SendAsync(string goal, bool planApproved = false, bool echoUser = true)
    {
        if (chatController == null || chatController.Running)
        {
            return;
        }

        var attachment = pendingAttachment;
        pendingAttachment = null;
        Chat.Model.ClearAttachment();
        var body = goal.Length > 0
            ? goal
            : attachment != null ? Describe(attachment) : "";

        if (tray != null)
        {
            tray.Tooltip = "HOPA (working)";
            tray.StopEnabled = true;
        }

        TakeoverButton.Visibility = Visibility.Visible;
        StatusText.Text = "Working...";
        Chat.ScrollToEnd();
        try
        {
            var report = await chatController.SendAsync(body, attachment, planApproved, echoUser);
            if (report.Plan is { Count: > 0 } plan)
            {
                var approved = new PlanWindow(body, plan) { Owner = this }.ShowDialog() == true;
                if (approved)
                {
                    await SendAsync(body, planApproved: true, echoUser: false);
                }
                else
                {
                    StatusText.Text = "Plan not approved.";
                }

                return;
            }

            if (report.Error != null)
            {
                StatusText.Text = report.Error;
                Log($"error: {report.Error}");
                return;
            }

            Log($"HOPA: {report.Answer}");
            if (report.ModelInput.Length > 0)
            {
                Log($"model input: {report.ModelInput}");
            }
            if (!IsActive)
            {
                var preview = report.Answer.Length > 140 ? report.Answer[..140] + "..." : report.Answer;
                tray?.ShowBalloon("HOPA", preview);
            }
            foreach (var line in RunStepRow.Lines(report.Steps))
            {
                Log($"step {line}");
            }

            if (report.Steps is { Count: > 0 })
            {
                Log($"chain: {(report.ChainOk ? "ok" : "failed")}");
            }

            TitleText.Text = report.Title;
            Rail.Model.ShowTurn(report.Steps, report.ChainOk, report.Elapsed, report.Earlier);
            Chat.ScrollToEnd();
            StatusText.Text = "";
        }
        finally
        {
            if (tray != null)
            {
                tray.Tooltip = "HOPA";
                tray.StopEnabled = false;
            }

            TakeoverButton.Visibility = Visibility.Collapsed;
            WriteLog();
        }
    }

    private async Task SendFromComposerAsync()
    {
        if (chatController?.Running == true)
        {
            client?.CancelTurn();
            StatusText.Text = "Stopping...";
            return;
        }

        var goal = Chat.Model.ComposerText.Trim();
        if (goal.Length == 0 && pendingAttachment == null)
        {
            return;
        }

        if (chatController?.CurrentId is { } current)
        {
            Chat.Model.Drafts[current] = "";
        }

        Chat.Model.ComposerText = "";
        await SendAsync(goal);
    }


    private void MarkSelected(string? id) => Sidebar.Model.MarkSelected(id);

    protected override void OnPreviewKeyDown(KeyEventArgs e)
    {
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0)
        {
            switch (e.Key)
            {
                case Key.N:
                    _ = NewChatAsync();
                    e.Handled = true;
                    break;
                case Key.F:
                case Key.K:
                    Sidebar.FocusSearch();
                    e.Handled = true;
                    break;
            }
        }

        if (e.Key == Key.Escape)
        {
            if (chatController?.Running == true)
            {
                client?.CancelTurn();
            }

            speech?.SpeakAsyncCancelAll();
            voice.StopPlayback();
        }

        base.OnPreviewKeyDown(e);
    }



    private async Task NewChatAsync()
    {
        if (chatController == null)
        {
            return;
        }

        var row = await chatController.CreateAsync();
        if (row == null)
        {
            return;
        }

        Sidebar.ClearSearch();
        Sidebar.Model.ApplyFilter();
        MarkSelected(row.Id);
        await SelectAsync(row.Id);
    }

}
