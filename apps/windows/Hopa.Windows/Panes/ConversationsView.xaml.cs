using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using Hopa.Windows.Chat;

namespace Hopa.Windows.Panes;

/// <summary>The sidebar control. It renders the rows and raises what the window should do.</summary>
public partial class ConversationsView : UserControl
{
    private bool switching;

    public ConversationsView()
    {
        InitializeComponent();
        DataContext = Model;
        var source = new CollectionViewSource { Source = Model.Visible };
        source.GroupDescriptions.Add(new PropertyGroupDescription("GroupLabel"));
        ConversationList.ItemsSource = source.View;
    }

    public ConversationsViewModel Model { get; } = new();

    public event Action? NewChatRequested;

    public event Action? SettingsRequested;

    public event Action? BridgeHintRequested;

    public event Action? IncludeArchivedChanged;

    public event Action<ConversationRow>? SelectionChanged;

    public event Action<ConversationRow>? PinRequested;

    public event Action<ConversationRow>? ArchiveRequested;

    public event Action<ConversationRow>? RenameRequested;

    public event Action<ConversationRow>? DeleteRequested;

    public event Action<ConversationRow>? ExportRequested;

    /// <summary>Marks a row in the list without treating it as a user click.</summary>
    public void Select(ConversationRow? row)
    {
        switching = true;
        ConversationList.SelectedItem = row;
        switching = false;
    }

    public void FocusSearch()
    {
        SearchBox.Focus();
        SearchBox.SelectAll();
    }

    public void ClearSearch() => SearchBox.Clear();

    private ConversationRow? ActionRow => ConversationList.SelectedItem as ConversationRow;

    private void NewChat_Click(object sender, RoutedEventArgs e) => NewChatRequested?.Invoke();

    private void Settings_Click(object sender, RoutedEventArgs e) => SettingsRequested?.Invoke();

    private void NoBridge_Click(object sender, MouseButtonEventArgs e) => BridgeHintRequested?.Invoke();

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e) =>
        SearchPlaceholder.Visibility =
            SearchBox.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;

    private void ShowArchived_Click(object sender, RoutedEventArgs e)
    {
        Model.IncludeArchived = ShowArchivedBox.IsChecked == true;
        IncludeArchivedChanged?.Invoke();
    }

    private void ConversationList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (switching || ConversationList.SelectedItem is not ConversationRow row)
        {
            return;
        }

        SelectionChanged?.Invoke(row);
    }

    private void More_Click(object sender, MouseButtonEventArgs e)
    {
        if (sender is not FrameworkElement element || element.DataContext is not ConversationRow row)
        {
            return;
        }

        ConversationList.SelectedItem = row;
        if (ConversationList.ContextMenu is { } menu)
        {
            menu.PlacementTarget = element;
            menu.IsOpen = true;
        }

        e.Handled = true;
    }

    private void Pin_Click(object sender, RoutedEventArgs e)
    {
        if (ActionRow is { } row)
        {
            PinRequested?.Invoke(row);
        }
    }

    private void Archive_Click(object sender, RoutedEventArgs e)
    {
        if (ActionRow is { } row)
        {
            ArchiveRequested?.Invoke(row);
        }
    }

    private void Rename_Click(object sender, RoutedEventArgs e)
    {
        if (ActionRow is { } row)
        {
            RenameRequested?.Invoke(row);
        }
    }

    private void Export_Click(object sender, RoutedEventArgs e)
    {
        if (ActionRow is { } row)
        {
            ExportRequested?.Invoke(row);
        }
    }

    private void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (ActionRow is { } row)
        {
            DeleteRequested?.Invoke(row);
        }
    }
}
