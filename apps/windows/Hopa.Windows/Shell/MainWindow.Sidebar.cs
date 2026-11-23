using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using Hopa.Windows.Chat;
using Hopa.Windows.Dialogs;
using Microsoft.Win32;

namespace Hopa.Windows.Shell;

public partial class MainWindow : Window
{
    /// <summary>Reloads the sidebar after the archive switch asks for a wider list.</summary>
    private async Task ReloadConversationsAsync()
    {
        if (chatController == null)
        {
            return;
        }

        await chatController.LoadAsync(
            Sidebar.Model.IncludeArchived,
            createIfEmpty: false);
    }

    private async Task PinAsync(ConversationRow row)
    {
        if (client == null)
        {
            return;
        }

        var pinned = !row.Pinned;
        if (await client.PinConversationAsync(row.Id, pinned) != null)
        {
            row.Pinned = pinned;
            Sidebar.Model.ApplyFilter();
        }
    }

    private async Task ArchiveAsync(ConversationRow row)
    {
        if (client == null)
        {
            return;
        }

        var archived = !row.Archived;
        if (await client.ArchiveConversationAsync(row.Id, archived) == null)
        {
            return;
        }

        row.Archived = archived;
        Sidebar.Model.ApplyFilter();
        if (archived && !Sidebar.Model.IncludeArchived && chatController?.CurrentId == row.Id)
        {
            chatController.Forget();
            Chat.Model.ShowConversation(messages: null, draft: "");
            if (Sidebar.Model.All.FirstOrDefault(item => !item.Archived) is { } next)
            {
                await SelectAsync(next.Id);
            }
        }
    }

    private async Task RenameAsync(ConversationRow row)
    {
        if (client == null)
        {
            return;
        }

        var dialog = new RenameWindow(row.Title) { Owner = this };
        if (dialog.ShowDialog() != true || dialog.TitleValue.Length == 0)
        {
            return;
        }

        var renamed = await client.RenameConversationAsync(row.Id, dialog.TitleValue);
        if (renamed?["title"]?.GetValue<string>() is { } title)
        {
            row.Title = title;
            TitleText.Text = title;
        }
    }

    private async Task DeleteAsync(ConversationRow row)
    {
        if (client == null)
        {
            return;
        }

        if (MessageBox.Show($"Delete \"{row.Title}\"?", "HOPA", MessageBoxButton.OKCancel,
                MessageBoxImage.Question) != MessageBoxResult.OK)
        {
            return;
        }

        if (!await client.DeleteConversationAsync(row.Id))
        {
            return;
        }

        Sidebar.Model.Remove(row);
        if (chatController?.CurrentId != row.Id)
        {
            return;
        }

        chatController.Forget();
        Chat.Model.ShowConversation(messages: null, draft: "");
        if (Sidebar.Model.All.FirstOrDefault() is { } next)
        {
            await SelectAsync(next.Id);
        }
        else
        {
            await RefreshAsync();
        }
    }

    private async Task ExportAsync(ConversationRow row)
    {
        if (client == null)
        {
            return;
        }

        var json = await client.ExportConversationAsync(row.Id);
        var dialog = new SaveFileDialog
        {
            FileName = $"{row.Title}.json",
            Filter = "JSON|*.json",
        };
        if (dialog.ShowDialog() == true)
        {
            File.WriteAllText(dialog.FileName, json);
        }
    }
}
