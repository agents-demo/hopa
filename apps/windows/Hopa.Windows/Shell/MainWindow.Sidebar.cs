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
using Hopa.Windows.Chat;
using Hopa.Windows.Checks;
using Hopa.Windows.Dialogs;
using Hopa.Windows.Device;
using Hopa.Windows.Engine;
using Hopa.Windows.Gateway;
using Hopa.Windows.Storage;
using Hopa.Windows.Voice;

namespace Hopa.Windows.Shell;

public partial class MainWindow : Window
{
    private void UpdateSearchPlaceholder() =>
        SearchPlaceholder.Visibility = SearchBox.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        UpdateSearchPlaceholder();
        ApplyFilter();
    }

    private void ApplyFilter()
    {
        var query = SearchBox.Text.Trim();
        var showArchived = ShowArchivedBox.IsChecked == true;
        var ordered = allConversations
            .OrderByDescending(item => item.Pinned)
            .ThenByDescending(item => item.UpdatedAt)
            .ToList();
        conversations.Clear();
        foreach (var conversation in ordered)
        {
            if (!showArchived && conversation.Archived)
            {
                continue;
            }

            if (query.Length == 0 ||
                conversation.SearchText.Contains(query, StringComparison.OrdinalIgnoreCase))
            {
                conversations.Add(conversation);
            }
        }
    }

    private async void ShowArchived_Click(object sender, RoutedEventArgs e)
    {
        if (client == null)
        {
            return;
        }

        var items = await client.ListConversationsAsync(ShowArchivedBox.IsChecked == true);
        allConversations.Clear();
        foreach (var item in items)
        {
            allConversations.Add(ConversationRow.From(item));
        }

        ApplyFilter();
    }

    private void More_Click(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (sender is not FrameworkElement element || element.DataContext is not ConversationRow vm)
        {
            return;
        }

        ConversationList.SelectedItem = vm;
        if (ConversationList.ContextMenu is { } menu)
        {
            menu.PlacementTarget = element;
            menu.IsOpen = true;
        }

        e.Handled = true;
    }

    private async void Pin_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || ConversationList.SelectedItem is not ConversationRow vm)
        {
            return;
        }

        var pinned = !vm.Pinned;
        if (await client.PinConversationAsync(vm.Id, pinned) != null)
        {
            vm.Pinned = pinned;
            ApplyFilter();
        }
    }

    private async void Archive_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || ConversationList.SelectedItem is not ConversationRow vm)
        {
            return;
        }

        var archived = !vm.Archived;
        if (await client.ArchiveConversationAsync(vm.Id, archived) != null)
        {
            vm.Archived = archived;
            ApplyFilter();
            if (archived && !ShowArchivedBox.IsChecked.GetValueOrDefault() && currentId == vm.Id)
            {
                currentId = null;
                messages.Clear();
                if (allConversations.Any(item => !item.Archived))
                {
                    await SelectAsync(allConversations.First(item => !item.Archived).Id);
                }
            }
        }
    }

    private async void Rename_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || ConversationList.SelectedItem is not ConversationRow vm)
        {
            return;
        }

        var dialog = new RenameWindow(vm.Title) { Owner = this };
        if (dialog.ShowDialog() != true || dialog.TitleValue.Length == 0)
        {
            return;
        }

        var renamed = await client.RenameConversationAsync(vm.Id, dialog.TitleValue);
        if (renamed?["title"]?.GetValue<string>() is { } title)
        {
            vm.Title = title;
            TitleText.Text = title;
        }
    }

    private async void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || ConversationList.SelectedItem is not ConversationRow vm)
        {
            return;
        }

        if (MessageBox.Show($"Delete \"{vm.Title}\"?", "HOPA", MessageBoxButton.OKCancel,
                MessageBoxImage.Question) != MessageBoxResult.OK)
        {
            return;
        }

        if (!await client.DeleteConversationAsync(vm.Id))
        {
            return;
        }

        allConversations.Remove(vm);
        ApplyFilter();
        if (currentId == vm.Id)
        {
            currentId = null;
            messages.Clear();
            if (allConversations.Count > 0)
            {
                await SelectAsync(allConversations[0].Id);
            }
            else
            {
                await RefreshAsync();
            }
        }
    }

    private async void Export_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || ConversationList.SelectedItem is not ConversationRow vm)
        {
            return;
        }

        var json = await client.ExportConversationAsync(vm.Id);
        var dialog = new SaveFileDialog
        {
            FileName = $"{vm.Title}.json",
            Filter = "JSON|*.json",
        };
        if (dialog.ShowDialog() == true)
        {
            File.WriteAllText(dialog.FileName, json);
        }
    }
}
